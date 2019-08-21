using Test, GitHubAPI

@testset "Search" begin
    @test parse_repos!("postgresql")
    @test parse_repos!("postgresql",
                       "2019-10-29T14:37:16+00:00..2019-08-15T00:00:00-04:00")
end
@testset "Repository" begin
    @test parse_commits!("uva-bi-sdad/GitHubAPI.jl")
    @test parse_commits!("uva-bi-sdad/GitHubAPI.jl", "2018-08-12 17:29:38+00")
end

created_at = "2009-04-20T01:17:36+00:00..2009-12-11T14:57:45+00:00"

result = GitHubAPI.client.Query(GitHubAPI.github_api_query,
                                operationName = "Search",
                                vars = Dict("license_created" =>
                                            """
                                            license:$license
                                            created:$created_at
                                            """))
as_of = GitHubAPI.get_as_of(result.Info)
json = GitHubAPI.JSON3.read(result.Data)
@assert(haskey(json, :data))
data = json.data
GitHubAPI.github_wait_out(data.rateLimit)
repositoryCount = data.search.repositoryCount
licenses = get_licenses()

license = "Apache-2.0"
for license in licenses[findfirst(isequal("Apache-2.0"), licenses):end]
    parse_repos!(license, "2014-04-10T08:56:48+00:00..2014-04-14T04:29:01+00:00")
end
