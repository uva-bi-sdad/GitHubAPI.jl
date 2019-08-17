"""
    GitHubAPI
Module used by the Social Decision and Analytics Division (SDAD) of
the Biocomplexity Institute and Initiative of the University of Virginia.

This module was designed for the Open-Source Software (OSS) project.
"""
module GitHubAPI
    using ConfParser: ConfParse, parse_conf!, retrieve, save!, commit!
    using Diana: GraphQLClient,
                 # HTTP
                 HTTP.Messages.Response, HTTP.request
    using JSON3: JSON3
    using LibPQ: Connection, execute
    using Parameters: @unpack
    using TimeZones: localzone, now, today, yearmonthday, ZonedDateTime,
                     # Dates
                     @dateformat_str, Dates.format
    """
        sdad_setup!(;db_user::AbstractString = "",
                     db_pwd::AbstractString = "",
                     github_login::AbstractString = "",
                     github_token::AbstractString = "")
    This function writes the configurations to `confs/config.simple`
    # Arguments
    - `db_user`: Your username for the `postgis_1` [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe) (i.e., your UVA computing ID).
    - `db_pwd`: The password for the `postgis_1` [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
    - `github_login`: Your GitHub login (handle).
    - `github_token`: A 40 alphanumeric characters string. Obtain a GitHub personal access token [here](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line).
    # Examples
    ## Good!
    ```
    julia> sdad_setup!(db_user = "jbs3hp",
                       db_pwd = "MyVerySafePwd",
                       github_login = "Nosferican",
                       github_token = "0ipg0jvonteb54lv7j6cbgwn2snq3d3ac1pthxvz")
    😃
    ```
    ## Incomplete!
    ```
    julia> sdad_setup!(db_user = "jbs3hp",
                       db_pwd = "MyVerySafePwd",
                       github_login = "Nosferican")
    Warning: github_login has not been defined.
    😞
    ```
    # Updating the configuration file.
    ```
    julia> using GitHubAPI
    julia> sdad_setup!(db_user = "jbs3hp",
                       db_pwd = "MyVerySafePwd",
                       github_login = "Nosferican",
                       github_token = "0ipg0jvonteb54lv7j6cbgwn2snq3d3ac1pthxvz")
    julia> exit()
    > julia
    julia> using GitHubAPI # config up-to-date
    ```
    !!! note
        Updating the configuration file requires a restart of the session.
    # Updating the GitHub personal access token
    ## Permanent through the configuration file
    ```
    julia> sdad_setup!(github_token = "0ipg0jvonteb54lv7j6cbgwn2snq3d3ac1pthxvz")
    😃
    ```
    ## Temporarily
    ```
    GitHubAPI.github_token = "0ipg0jvonteb54lv7j6cbgwn2snq3d3ac1pthxvz" # new value
    ```
    !!! note
        This method is temporary and will note overwrite the configuration file.
        Only the GitHub personal access token is allowed to be modified temporarily.
    """
    function sdad_setup!(;db_user::AbstractString = "",
                          db_pwd::AbstractString = "",
                          github_login::AbstractString = "",
                          github_token::AbstractString = "")
        args = ["db_user", "db_pwd", "github_login", "github_token"]
        isdir(joinpath(dirname(@__DIR__), "confs")) ||
            mkdir(joinpath(dirname(@__DIR__), "confs"))
        isfile(joinpath(dirname(@__DIR__), "config.simple")) ||
            touch(joinpath(dirname(@__DIR__), "confs", "config.simple"))
        conf = ConfParse(joinpath(dirname(@__DIR__), "confs", "config.simple"),
                         "simple")
        parse_conf!(conf)
        for (key, val) ∈ zip(args, [db_user, db_pwd, github_login, github_token])
            isempty(val) || commit!(conf, key, val)
        end
        save!(conf)
        notdefined = filter(key -> !haskey(conf, key),
                            args)
        foreach(key -> @warn("$key has not been defined."),
                notdefined)
        if isinteractive()
            if isempty(notdefined)
                println("😃")
            else
                println("😞")
            end
        end
    end
    isfile(joinpath(dirname(@__DIR__), "config.simple")) ||
        sdad_setup!()
    conf = ConfParse("confs/config.simple");
    parse_conf!(conf);
    """
        db_user::String
    The username for the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe) (i.e., your UVA computing ID).
    """
    const db_user = retrieve(conf, "db_user");
    """
        db_pwd::String
    The password for the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
    """
    const db_pwd = retrieve(conf, "db_pwd");
    """
        github_login::String
    Your GitHub handle.
    """
    const github_login = retrieve(conf, "github_login");
    """
        github_header = Dict("User-Agent" => github_login)
    Header for the GitHub API.
    """
    const github_header = Dict("User-Agent" => github_login);
    github_token = retrieve(conf, "github_token");
    # SDAD Database [OSS prj]
    """
        db_host = "sdad.policy-analytics.net"
    Host for the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
    """
    const db_host = "sdad.policy-analytics.net";
    """
        db_port = 5434
    Port for the `postgis_1` in the [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe).
    """
    const db_port = 5434;
    """
        dbname = "oss"
    Database for the Open-Source Software project.
    """
    const dbname = "oss";
    # GitHub
    """
        github_endpoint = "https://api.github.com/graphql"
    Endpoint for the GitHub API v4 (GraphQL).
    """
    const github_endpoint = "https://api.github.com/graphql";
    # Queries depending on the stage
    """
        github_api_query::String
    Query for getting the repository information from GitHub based on license.
    """
    const github_api_query = """
        query LicenseCreated(\$license_created: String!) {
          ...RateLimit
          search(query: \$license_created,
                 type: REPOSITORY,
                 first: 100) {
            ...Main
          }
        }
        query Cursor(\$license_created: String!,
                     \$cursor: String!) {
          ...RateLimit
          search(query: \$license_created,
                 type: REPOSITORY,
                 first: 100,
                 after: \$cursor) {
            ...Main
          }
        }
        fragment RateLimit on Query {
          rateLimit {
            remaining
            resetAt
          }
        }
        fragment Main on SearchResultItemConnection {
          repositoryCount
          pageInfo {
            endCursor
            hasNextPage
          }
          nodes {
            ... on Repository {
              isPrivate
              databaseId
              nameWithOwner
              createdAt
              isArchived
              isFork
              isMirror
            }
          }
        }
        """;
    """
        response_dtf = dateformat"d u y H:M:S Z"
    HTTP responses require this datetime format.
    """
    const response_dtf = dateformat"d u y H:M:S Z";
    """
        github_dtf = "yyyy-mm-ddTHH:MM:SSzzzz"
    GitHub zoned datetime format.
    """
    const github_dtf = "yyyy-mm-ddTHH:MM:SSzzzz";
    # until = today() |>
    #     yearmonthday |>
    #     (dt -> ZonedDateTime(dt..., localzone()))
    #     (td -> ZonedDateTime(year(td), month(td), day(td), localzone()));
    """
        until::ZonedDateTime
    Until when should the scrapper query data. Currently at `"2019-08-15T00:00:00-04:00"`.
    """
    until = ZonedDateTime("2019-08-15T00:00:00-04:00",
                          github_dtf)
    """
        binary_search_dt_interval(license::AbstractString,
                                  interval::AbstractString)::data, as_of, created_at
    Given a license and a datetime interval, it will use binary search to find
    a datetime interval with no more than 1,000 results.
    """
    @inline function binary_search_dt_interval(license::AbstractString,
                                               created_at::AbstractString)
        dt_start = match(r".*(?=\.{2})", created_at)
        if isnothing(dt_start)
            dt_start = replace(created_at, r"Z$" => "+00:00") |>
                (dt -> ZonedDateTime(dt, github_dtf))
        else
            dt_start = match(r".*(?=\.\.)", created_at).match |>
                (dt -> replace(dt, r"Z$" => "+00:00")) |>
                (dt -> ZonedDateTime(dt, github_dtf))
        end
        dt_end = match(r"(?<=\.{2}).*", created_at)
        if isnothing(dt_end)
            dt_end = until
        else
            dt_end = match(r"(?<=\.{2}).*", created_at).match |>
                (dt -> replace(dt, r"Z$" => "+00:00")) |>
                (dt -> ZonedDateTime(dt, github_dtf))
        end
        result = client.Query(github_api_query,
                              operationName = "LicenseCreated",
                              vars = Dict("license_created" =>
                                          """
                                          license:$license
                                          created:$dt_start..$dt_end
                                          """))
        as_of = get_as_of(result.Info)
        json = JSON3.read(result.Data)
        @assert(haskey(json, :data))
        data = json.data
        github_wait_out(data.rateLimit)
        repositoryCount = data.search.repositoryCount
        while repositoryCount > 1_000
            dt_end = dt_start + (dt_end - dt_start) ÷ 2 |>
                (dt -> format(dt, github_dtf)) |>
                (dt -> ZonedDateTime(dt, github_dtf))
            result = client.Query(github_api_query,
                                  operationName = "LicenseCreated",
                                  vars = Dict("license_created" =>
                                              """
                                              license:$license
                                              created:$dt_start..$dt_end
                                              """))
            as_of = get_as_of(result.Info)
            json = JSON3.read(result.Data)
            @assert(haskey(json, :data))
            data = json.data
            github_wait_out(data.rateLimit)
            repositoryCount = data.search.repositoryCount
        end
        data.search, as_of, "$dt_start..$dt_end"
    end
    # Postgis
    """
        dbconnect()::Connection
    Returns a connection to the `postgis_1` OSS [database](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe) (i.e., your UVA computing ID).

    # Example

    ```
    conn = dbconnect()
    ```
    """
    function dbconnect()
        (@isdefined(db_user) && @isdefined(db_pwd)) ||
            throw(ArgumentError("Run sdad_setup! before making a connection."))
        Connection("""
                   host = $db_host
                   port = $db_port
                   dbname = $dbname
                   user = $db_user
                   password = $db_pwd
                   """)
    end
    """
        get_licenses(conn::Connection)::Vector{String}
    List of SPDX ID for every OSI-approved license. (source: [SPDX](https://github.com/spdx/license-list-data))
    """
    get_licenses(conn::Connection) =
        execute(dbconnect(), "select id from licenses where osi") |>
        (licenses -> getproperty.(licenses, :id))
    # execute(conn,
    #         """
    #         create table universe.github_repos(
    #           id int not null,
    #           slug varchar not null,
    #           created_at timestamptz not null,
    #           is_archived bool not null,
    #           is_fork bool not null,
    #           is_mirror bool not null,
    #           spdx varchar not null,
    #           query char(52) not null,
    #           as_of timestamptz not null,
    #           primary key (id)
    #         )
    #         """)
    # execute(conn,
    #         """
    #         create table universe.github_repos_tracker(
    #           spdx varchar(36) not null,
    #           query char(52) not null,
    #           total int not null,
    #           primary key (spdx, query)
    #         )
    #         """)
    # GraphQL
    # client = GraphQLClient(github_endpoint,
    #                        auth = "bearer $github_token",
    #                        headers = github_header)
    """
        get_as_of(response::Response)::String
    Returns the zoned date time when the response was returned.
    """
    get_as_of(response::Response) =
        response.headers[findfirst(x -> isequal("Date", x.first),
                                   response.headers)].second[6:end] |>
            (dt -> ZonedDateTime(dt, response_dtf)) |>
            string
    """
        insert_record_repos_by_license!(conn::Connection,
                                        license::AbstractString,
                                        created_at::AbstractString,
                                        as_of::AbstractString,
                                        node)
    It inserts each record to the `universe.github_repos` table.
    """
    function insert_record_repos_by_license!(conn::Connection,
                                             license::AbstractString,
                                             created_at::AbstractString,
                                             as_of::AbstractString,
                                             node)
        @unpack isPrivate, databaseId, nameWithOwner, createdAt,
                isArchived, isFork, isMirror = node
        node.isPrivate && return
        execute(conn,
                """insert into universe.github_repos values(
                   '$databaseId', '$nameWithOwner', '$createdAt',
                   $isArchived, $isFork, $isMirror,
                   '$license', '$created_at', '$as_of'
                   )
                   on conflict (id) do update set
                   slug = excluded.slug,
                   is_archived = excluded.is_archived,
                   is_fork = excluded.is_fork,
                   is_mirror = excluded.is_mirror,
                   spdx = excluded.spdx,
                   created_at = excluded.created_at,
                   as_of = excluded.as_of
                """)
    end
    """
        github_wait_out(rateLimit)
    If the GitHub personal access token has exhausted the per hour limit,
    it waits until it resets.
    """
    github_wait_out(rateLimit) =
        iszero(rateLimit.remaining) &&
            ZonedDateTime(replace("2019-08-14T23:02:00-04:00", r"Z$" => "+00:00"),
                          "yyyy-mm-ddTHH:MM:SSzzzzz") - now(localzone()) |>
                sleep
    """
        parse_repos!(conn::Connection,
                     license::AbstractString,
                     created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                     until::ZonedDateTime = until)
        parse_repos!(conn::Connection,
                     license::AbstractString,
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
    conn = dbconnect()
    parse_repos!(conn, "zlib")
    ```

    After checking the [`github_repos_tracker`](http://sdad.policy-analytics.net:8080/?pgsql=postgis_1&db=oss&ns=universe&select=github_repos_tracker),

    If the license scrapper already has completed some work, you can resume the job
    by passing the `created_at` argument.

    ```
    parse_repos!(conn,
                 "zlib",
                 "2016-04-20T15:59:13+00:00..2017-12-17T09:59:36+00:00")
    ```
    """
    function parse_repos!(conn::Connection,
                          license::AbstractString,
                          created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                          until::ZonedDateTime = until)
        (@isdefined(db_user) && @isdefined(db_pwd) &&
            @isdefined(github_login) && @isdefined(github_token)) ||
            throw(ArgumentError("Run sdad_setup! before making a connection."))
        data, as_of, created_at = binary_search_dt_interval(license, created_at)
        hasNextPage = data.pageInfo.hasNextPage
        cursor = data.pageInfo.endCursor
        execute(conn,
                """insert into universe.github_repos_tracker values(
                   '$license', '$created_at', $(data.repositoryCount)
                   )
                   on conflict (spdx, query) do update set
                   total = excluded.total
                """)
        foreach(node -> insert_record_repos_by_license!(conn,
                                                        license, created_at, as_of,
                                                        node),
                data.nodes)
        while hasNextPage
            result = client.Query(github_api_query,
                                  operationName = "Cursor",
                                  vars = Dict("license_created" =>
                                              "license:$license created:$created_at",
                                              "cursor" => cursor))
            as_of = get_as_of(result.Info)
            json = JSON3.read(result.Data)
            @assert(haskey(json, :data))
            data = json.data
            github_wait_out(data.rateLimit)
            hasNextPage = data.search.pageInfo.hasNextPage
            cursor = data.search.pageInfo.endCursor
            foreach(node -> insert_record_repos_by_license!(conn,
                                                            license, created_at, as_of,
                                                            node),
                    data.search.nodes)
        end
        dt_end = match(r"(?<=\.\.).*", created_at).match |>
            (dt -> ZonedDateTime(dt, github_dtf))
        created_at = "$dt_end..$until"
        data, as_of, created_at = binary_search_dt_interval(license, created_at)
        iszero(data.repositoryCount) ||
            parse_repos!(conn, license, data, as_of, created_at, until)
    end
    function parse_repos!(conn::Connection,
                          license::AbstractString,
                          data,
                          as_of,
                          created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                          until::ZonedDateTime = until)
        (@isdefined(db_user) && @isdefined(db_pwd) &&
            @isdefined(github_login) && @isdefined(github_token)) ||
            throw(ArgumentError("Run sdad_setup! before making a connection."))
        hasNextPage = data.pageInfo.hasNextPage
        cursor = data.pageInfo.endCursor
        execute(conn,
                """insert into universe.github_repos_tracker values(
                   '$license', '$created_at', $(data.repositoryCount)
                   )
                   on conflict (spdx, query) do update set
                   total = excluded.total
                """)
        foreach(node -> insert_record_repos_by_license!(conn,
                                                        license, created_at, as_of,
                                                        node),
                data.nodes)
        while hasNextPage
            result = client.Query(github_api_query,
                                  operationName = "Cursor",
                                  vars = Dict("license_created" =>
                                              "license:$license created:$created_at",
                                              "cursor" => cursor))
            as_of = get_as_of(result.Info)
            json = JSON3.read(result.Data)
            @assert(haskey(json, :data))
            data = json.data
            github_wait_out(data.rateLimit)
            hasNextPage = data.search.pageInfo.hasNextPage
            cursor = data.search.pageInfo.endCursor
            foreach(node -> insert_record_repos_by_license!(conn,
                                                            license, created_at, as_of,
                                                            node),
                    data.search.nodes)
        end
        dt_end = match(r"(?<=\.\.).*", created_at).match |>
            (dt -> ZonedDateTime(dt, github_dtf))
        created_at = "$dt_end..$until"
        data, as_of, created_at = binary_search_dt_interval(license, created_at)
        iszero(data.repositoryCount) ||
            parse_repos!(conn, license, data, as_of, created_at, until)
    end
    export get_licenses, dbconnect, parse_repos!, sdad_setup!
end
