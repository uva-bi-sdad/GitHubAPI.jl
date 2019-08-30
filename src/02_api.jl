# GitHub
"""
    github_endpoint = "https://api.github.com/graphql"
Endpoint for the GitHub API v4 (GraphQL).
"""
const github_endpoint = "https://api.github.com/graphql";
"""
    client = GraphQLClient(github_endpoint,
                           auth = "bearer \$github_token",
                           headers = github_header)
Client for the GitHub API.
"""
const client = GraphQLClient(github_endpoint,
                             auth = "bearer $github_token",
                             headers = github_header)
"""
    github_api_query::String
Queries for finding open-sourced projects and their commit information from GitHub.
"""
const github_api_query = """
    query Search(\$license_created: String!) {
      ...RateLimit
      search(query: \$license_created,
             type: REPOSITORY,
             first: 100) {
        ...SearchLogic
      }
    }
    query SearchCursor(\$license_created: String!,
                 \$cursor: String!) {
      ...RateLimit
      search(query: \$license_created,
             type: REPOSITORY,
             first: 100,
             after: \$cursor) {
        ...SearchLogic
      }
    }
    query Repository(\$owner: String!,
                     \$name: String!,
                     \$until: GitTimestamp!) {
      ...RateLimit
      ...Repo
    }
    query RepositoryCursor(\$owner: String!,
                           \$name: String!,
                           \$until: GitTimestamp!,
                           \$cursor: String!) {
      ...RateLimit
      ...RepoCursor
    }
    fragment RateLimit on Query {
      rateLimit {
        remaining
        resetAt
      }
    }
    fragment SearchLogic on SearchResultItemConnection {
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
    fragment CommitHistory on CommitHistoryConnection {
      totalCount
      pageInfo {
        endCursor
        hasNextPage
      }
      nodes {
        author {
          user {
            login
          }
        }
        oid
        committedDate
        additions
        deletions
      }
    }
    fragment Repo on Query {
      repository(owner: \$owner, name: \$name) {
        defaultBranchRef {
          target {
            ... on Commit {
              history(first: 1, until: \$until) {
                ...CommitHistory
              }
            }
          }
        }
      }
    }
    fragment RepoCursor on Query {
      repository(owner: \$owner, name: \$name) {
        defaultBranchRef {
          target {
            ... on Commit {
              history(first: 100, until: \$until, after: \$cursor) {
                ...CommitHistory
              }
            }
          }
        }
      }
    }
    """;
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
                          operationName = "Search",
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
                              operationName = "Search",
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
    github_wait_out(rateLimit)
If the GitHub personal access token has exhausted the per hour limit,
it waits until it resets.
"""
github_wait_out(rateLimit) =
    iszero(rateLimit.remaining) &&
        ZonedDateTime(replace("2019-08-14T23:02:00-04:00", r"Z$" => "+00:00"),
                      "yyyy-mm-ddTHH:MM:SSzzzzz") - now(localzone()) |>
            sleep
