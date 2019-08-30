# Parsers
"""
    parse_repos!(license::AbstractString,
                 created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                 until::ZonedDateTime = until)
    parse_repos!(license::AbstractString,
                 data,
                 as_of,
                 created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                 until::ZonedDateTime = until)
For one a given license, it collects the information for each repository.

# Arguments

- `license` is a SPDX identifier for some OSI-approved license.
- `created_at` is a datetime interval that GitHub supports ([docs](https://help.github.com/en/articles/understanding-the-search-syntax#query-for-dates))
- `until`: this value is the end-date for the queries (`GitHubAPI.until`)


# Examples

Start querying for all the repositories with license `zlib`.

```
parse_repos!("zlib")
```

After checking the [`github_repos_tracker`](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe&select=github_repos_tracker),

If the license scrapper already has completed some work, you can resume the job by passing the `created_at` argument.

```
parse_repos!("zlib",
             "2016-04-20T15:59:13+00:00..2017-12-17T09:59:36+00:00")
```
"""
function parse_repos!(license::AbstractString,
                      created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                      until::ZonedDateTime = until)
    (@isdefined(db_user) && @isdefined(db_pwd) &&
        @isdefined(github_login) && @isdefined(github_token)) ||
        throw(ArgumentError("Run sdad_setup! before making a connection."))
    data, as_of, created_at = binary_search_dt_interval(license, created_at)
    conn = dbconnect()
    execute(conn,
            """insert into universe.github_repos_tracker values(
               '$license', '$created_at', $(data.repositoryCount)
               )
               on conflict (spdx, query) do update set
               total = excluded.total
            """)
    if !isempty(data.nodes)
        foreach(node -> insert_record_repos_by_license!(conn,
                                                        license, created_at, as_of,
                                                        node),
                data.nodes)
    end
    close(conn)
    while data.pageInfo.hasNextPage
        result = client.Query(github_api_query,
                              operationName = "SearchCursor",
                              vars = Dict("license_created" =>
                                          "license:$license created:$created_at",
                                          "cursor" => data.pageInfo.endCursor))
        as_of = get_as_of(result.Info)
        json = JSON3.read(result.Data)
        @assert(haskey(json, :data))
        data = json.data
        github_wait_out(data.rateLimit)
        data = data.search
        conn = dbconnect()
        if !isempty(data.nodes)
            foreach(node -> insert_record_repos_by_license!(conn,
                                                            license, created_at, as_of,
                                                            node),
                    data.nodes)
        end
        close(conn)
    end
    dt_end = match(r"(?<=\.\.).*", created_at).match |>
        (dt -> ZonedDateTime(dt, github_dtf))
    created_at = "$dt_end..$until"
    data, as_of, created_at = binary_search_dt_interval(license, created_at)
    iszero(data.repositoryCount) ||
        parse_repos!(license, data, as_of, created_at, until)
end
function parse_repos!(license::AbstractString,
                      data,
                      as_of,
                      created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                      until::ZonedDateTime = until)
    (@isdefined(db_user) && @isdefined(db_pwd) &&
        @isdefined(github_login) && @isdefined(github_token)) ||
        throw(ArgumentError("Run sdad_setup! before making a connection."))
    conn = dbconnect()
    execute(conn,
            """insert into universe.github_repos_tracker values(
               '$license', '$created_at', $(data.repositoryCount)
               )
               on conflict (spdx, query) do update set
               total = excluded.total
            """)
    if !isempty(data.nodes)
        foreach(node -> insert_record_repos_by_license!(conn,
                                                        license, created_at, as_of,
                                                        node),
                data.nodes)
    end
    close(conn)
    while data.pageInfo.hasNextPage
        result = client.Query(github_api_query,
                              operationName = "SearchCursor",
                              vars = Dict("license_created" =>
                                          "license:$license created:$created_at",
                                          "cursor" => data.pageInfo.endCursor))
        as_of = get_as_of(result.Info)
        json = JSON3.read(result.Data)
        @assert(haskey(json, :data))
        data = json.data
        github_wait_out(data.rateLimit)
        data = data.search
        conn = dbconnect()
        if !isempty(data.nodes)
            foreach(node -> insert_record_repos_by_license!(conn,
                                                            license, created_at, as_of,
                                                            node),
                    data.nodes)
        end
        close(conn)
    end
    dt_end = match(r"(?<=\.\.).*", created_at).match |>
        (dt -> ZonedDateTime(dt, github_dtf))
    created_at = "$dt_end..$until"
    data, as_of, created_at = binary_search_dt_interval(license, created_at)
    iszero(data.repositoryCount) ||
        parse_repos!(license, data, as_of, created_at, until)
end
"""
    parse_commits!(slug::AbstractString, until::AbstractString)
    parse_commits!(slug::AbstractString, until::ZonedDateTime = until)
Writes to the database all the commit history for that repository.
# Examples
## Query one repository.
```
parse_commits!("uva-bi-sdad/GitHubAPI.jl")
```
## For resuming work, find the date of the oldest commit in the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
```
parse_commits!("uva-bi-sdad/GitHubAPI.jl", "2019-01-01 15:30:00+00")
```
"""
parse_commits!(slug::AbstractString, until::AbstractString) =
    parse_commits!(slug, ZonedDateTime(until, postgis_dtf))
function parse_commits!(slug::AbstractString,
                        until::ZonedDateTime = until)
    (@isdefined(db_user) && @isdefined(db_pwd) &&
        @isdefined(github_login) && @isdefined(github_token)) ||
        throw(ArgumentError("Run sdad_setup! before making a connection."))
    owner, name = split(slug, '/')
    result = client.Query(github_api_query,
                          operationName = "Repository",
                          vars = Dict("owner" => owner,
                                      "name" => name,
                                      "until" => until))
    json = JSON3.read(result.Data)
    @assert(haskey(json, :data))
    github_wait_out(json.data.rateLimit)
    data = json.data.repository.defaultBranchRef.target.history
    conn = dbconnect()
    if !isempty(data.nodes)
        foreach(node -> insert_commit!(conn, slug, node), data.nodes)
    end
    close(conn)
    while data.pageInfo.hasNextPage
        try
            result = client.Query(github_api_query,
                                  operationName = "RepositoryCursor",
                                  vars = Dict("owner" => owner,
                                              "name" => name,
                                              "until" => until,
                                              "cursor" => data.pageInfo.endCursor))
            json = JSON3.read(result.Data)
            @assert(haskey(json, :data))
            github_wait_out(json.data.rateLimit)
            data = json.data.repository.defaultBranchRef.target.history
            conn = dbconnect()
            if !isempty(data.nodes)
                foreach(node -> insert_commit!(conn, slug, node), data.nodes)
            end
            close(conn)
        catch
            sleep(1)
        end
    end
    true
end
