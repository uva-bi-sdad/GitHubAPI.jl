"""
    GitHubAPI
Module used by the Social Decision and Analytics Division (SDAD) of
the Biocomplexity Institute and Initiative of the University of Virginia.

This module was designed for the Open-Source Software (OSS) project.
"""
module GitHubAPI
    using ConfParser: ConfParse, parse_conf!, retrieve
    using Diana: GraphQLClient, HTTP.Messages.Response, HTTP.request
    using JSON3: JSON3
    using LibPQ: Connection, execute
    using Parameters: @unpack
    using TimeZones: localzone, now, today, yearmonthday, ZonedDateTime,
                     # Dates
                     @dateformat_str, Dates.format
    # Reading configuration file
    conf = ConfParse("confs/config.simple");
    parse_conf!(conf);
    # SDAD Database [OSS prj]
    const db_host = "sdad.policy-analytics.net";
    const db_port = 5434;
    const dbname = "oss";
    const db_user = retrieve(conf, "db_user");
    const db_pwd = retrieve(conf, "db_pwd");
    # GitHub
    const github_endpoint = "https://api.github.com/graphql";
    const github_login = retrieve(conf, "github_login");
    github_token = retrieve(conf, "github_token");
    github_header = Dict("User-Agent" => github_login);
    # Queries depending on the stage
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
    const response_dtf = dateformat"d u y H:M:S Z";
    const github_dtf = "yyyy-mm-ddTHH:MM:SSzzzz";
    # until = today() |>
    #     yearmonthday |>
    #     (dt -> ZonedDateTime(dt..., localzone()))
    #     (td -> ZonedDateTime(year(td), month(td), day(td), localzone()));
    until = ZonedDateTime("2019-08-15T00:00:00-04:00",
                          github_dtf)
    """
        binary_search_dt_interval(license::AbstractString,
                                  interval::AbstractString)::data, as_of, created_at
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
        make_connection()::Connection
    Returns a connection to the OSS database.
    """
    make_connection() =
        Connection("""
                   host = $db_host
                   port = $db_port
                   dbname = $dbname
                   user = $db_user
                   password = $db_pwd
                   """)
    """
        LICENSES::Vector{String}
    A vector of every OSI-approved license (SPDX identifier).
    """
    const LICENSES = execute(make_connection(), "select id from licenses where osi") |>
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
    client = GraphQLClient(github_endpoint,
                           auth = "bearer $github_token",
                           headers = github_header)
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
    It inserts each record to the universe.github_repos table.
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
    If the GitHub personal token has exhausted the per hour limit,
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
                     created_at::AbstractString = "2007-10-29T14:37:16+00:00")
        parse_repos!(conn::Connection,
                     license::AbstractString,
                     data,
                     as_of,
                     created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                     until::ZonedDateTime = until)
    For one a given license, it collects the information for each repository.
    """
    function parse_repos!(conn::Connection,
                          license::AbstractString,
                          created_at::AbstractString = "2007-10-29T14:37:16+00:00",
                          until::ZonedDateTime = until)
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
    export LICENSES, make_connection, parse_repos!
end
