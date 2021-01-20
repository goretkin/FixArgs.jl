using MacroTools: MacroTools

# copied from MacroTools:
walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))

"""
    postwalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *after* they have been transformed by the walk.

See also: [`prewalk`](@ref).
"""
postwalk(f, x) = walk(x, x -> postwalk(f, x), f)

"""
    prewalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *before* they have been transformed by the walk, and the
walk will be applied to whatever `f` returns.

This makes `prewalk` somewhat prone to infinite loops; you probably want to try
[`postwalk`](@ref) first.
"""
prewalk(f, x)  = walk(f(x), x -> prewalk(f, x), identity)


"""
e.g.

```julia
julia> eval(uneval(Expr(:my_call, :arg1, :arg2)))
:($(Expr(:my_call, :arg1, :arg2)))

julia> eval(eval(uneval(:(sqrt(9)))))
3.0
```

Note the special case for `:(esc(x))`.
"""
function uneval(x::Expr)
    x.head === :escape && return x
    # the `Expr` below is assumed to be available in the scope and to be `Base.Expr`
    :(Expr($(uneval(x.head)), $(map(uneval, x.args)...)))
end

# tangential TODO: determine which one
uneval(x) = Meta.quot(x)
# uneval(x) = Meta.QuoteNode(x)

function do_escape(s::Symbol)
    return true
end

function do_escape(s::QuoteNode)
    @show s
    return true
end

function do_escape(e::Expr)
    e.head === :call && return false
    e.head === :-> && return false
    return true
end
# TODO if an expression is escaped, then do not keep recursing
# because right now generating e.g. `"(escape Base).((escape (inert sqrt)))"` which is invalid syntax.
escape_all_but(ex) = postwalk(x -> do_escape(x) ? esc(x) : x, ex)

"""
e.g.
julia> dump(let x = 9
       @xquote sqrt(x)
       end)
Expr
    head: Symbol call
    args: Array{Any}((2,))
        1: sqrt (function of type typeof(sqrt))
        2: Int64 9
"""
macro xquote(ex)
    uneval(escape_all_but(ex))
end


using Test: @test
expr_tests = [
    (
        (let x = 9
            @xquote sqrt(x)
        end),
        :($(sqrt)(9))
    ),
    (
        (let x = 9, sqrt=sin
            @xquote sqrt(x)
        end),
        :($(sin)(9))
    )
]

for t in expr_tests
    @test isequal(t[1], t[2])
end


# see TODO about escaping. these are not producing valid syntax.
#=
dump(let x = 9
    @xquote Base.sqrt(x)
end)

dump(let x = 9, sqrt=sin
    @xquote Base.sqrt(x)
end)
=#
