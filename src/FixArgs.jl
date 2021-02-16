module FixArgs

# export so that Julia v1.6 type alias printing works
# but not FixNew to not inhibit other type aliases: https://github.com/JuliaLang/julia/issues/39492
export Fix1, Fix2
export @xquote, @xquoteT

using FrankenTuples: FrankenTuples, FrankenTuple

include("parse.jl")
include("expr.jl")
include("show.jl")
include("types.jl")
include("eval.jl")
include("TypedExpressions.jl")
include("uneval.jl")
include("ergonomics.jl")

end
