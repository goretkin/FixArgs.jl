using Documenter
using FixArgs

DocMeta.setdocmeta!(FixArgs, :DocTestSetup, :(using FixArgs); recursive=true)

makedocs(
    modules = [FixArgs],
    sitename="FixArgs.jl",
    repo="https://github.com/goretkin/FixArgs.jl/blob/{commit}{path}#L{line}",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://goretkin.gitlab.io/FixArgs.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(
    repo = "github.com/goretkin/FixArgs.jl.git",
    deploy_config = Documenter.GitHubActions()
)
