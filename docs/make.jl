using Documenter
using Curry

DocMeta.setdocmeta!(Curry, :DocTestSetup, :(using Curry); recursive=true)

makedocs(
    modules = [Curry],
    sitename="Curry.jl",
    repo="https://github.com/goretkin/Curry.jl/blob/{commit}{path}#L{line}",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://goretkin.gitlab.io/Curry.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(
    repo = "github.com/goretkin/Curry.jl.git",
)
