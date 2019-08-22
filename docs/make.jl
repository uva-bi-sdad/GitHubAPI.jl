using Documenter, Weave, GitHubAPI

for file ∈ readdir(joinpath(dirname(pathof(GitHubAPI)), "..", "docs", "jmd"))
      weave(joinpath(dirname(pathof(GitHubAPI)), "..", "docs", "jmd", file),
            out_path = joinpath(dirname(pathof(GitHubAPI)), "..", "docs", "src"),
            doctype = "github")
end

makedocs(format = Documenter.HTML(assets = ["assets/custom.css"]),
         modules = [GitHubAPI],
         sitename = "GitHubAPI.jl",
         pages = ["Introduction" => "index.md",
                  "Getting Started" => "getting_started.md",
                  "Public API" => "public_api.md",
                  "Private API" => "private_api.md"]
    )

deploydocs(repo = "github.com/uva-bi-sdad/GitHubAPI.jl.git")
