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
