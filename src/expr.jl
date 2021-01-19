using MacroTools
using MacroTools: postwalk

function touch(ex)
    println(ex)
    return ex
end
postwalk_touch(ex) = postwalk(touch , ex)


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

escape_all_symbols(ex) = MacroTools.postwalk(x -> x isa Symbol ? esc(x) : x, ex)

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
    uneval(escape_all_symbols(ex))
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

# TODO escape Symbols and "." headed expressions so that the following work correctly.

dump(let x = 9
    @xquote Base.sqrt(x)
end)

dump(let x = 9, sqrt=sin
    @xquote Base.sqrt(x)
end)