using Documenter
using Curry

DocMeta.setdocmeta!(Curry, :DocTestSetup, :(using Curry); recursive=true)

makedocs(
    sitename = "Curry",
    format = Documenter.HTML(),
    modules = [Curry]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
