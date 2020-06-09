using Documenter
using Curry

DocMeta.setdocmeta!(Curry, :DocTestSetup, :(using Curry); recursive=true)

makedocs(
    modules = [Curry],
    sitename="Curry.jl",
    repo="https://github.com/goretkin/Curry.jl/blob/{commit}{path}#L{line}",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
