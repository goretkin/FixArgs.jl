# `FixArgs.Fix` is a combination of `Call` and `Lambda` below.
# Combining these two into one makes the common case of expressing e.g. `x -> x == 3` concise.
# However, it makes it difficult to express a bunch of expressions in `parse.jl`, as simple as `x -> x`,
# or `(f, x) -> f(x)` (which I think is possible with the split, but should check)
# or distinguish between
# `(x, y) -> f(x, g(y))`
# and
# `(x, y) -> f(x, () -> g(y))`

# In Julia 1.6 there is better printing of type aliases.
# So I think there should just be a type alias with the name e.g. `Fix` for the common case to be concise.
module New

# export so that Julia v1.6 type alias printing works
# but not FixNew to not inhibit other type aliases: https://github.com/JuliaLang/julia/issues/39492
export Fix1, Fix2

include("parse.jl")
include("expr.jl")
include("show.jl")
include("types.jl")
include("eval.jl")
include("TypedExpressions.jl")
include("uneval.jl")
include("ergonomics.jl")
end
