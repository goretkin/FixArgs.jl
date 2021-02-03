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

function uneval(x::TypedExpr)
    # the `TypedExpr` below is assumed to be available in the scope
    :(TypedExpr(
        $(uneval(x.head)),
        $(uneval(x.args))
    ))
end

function uneval(x::Val{T}) where T
    # assumed to be available in the scope
    :(Val($(uneval(T))))
end

function uneval(x::Tuple)
    Expr(:tuple, map(uneval, x)...)
    # :($(map(uneval, x)...))
end

uneval(x::Arity{P, KW}) where {P, KW} = :(Arity{$(uneval(P)), $(uneval(KW))}())
uneval(x::ArgPos{N}) where {N} = :(ArgPos($(uneval(N))))
uneval(x::ParentScope) = :(ParentScope($(uneval(x._))))

# TODO investigate difference between these two, (and in general, all `uneval`s) with respect to returning from a macro:
uneval(x::Lambda) = :(Lambda($(uneval(x.args)), $(uneval(x.body))))     # implementation 1
# uneval(x::Lambda) = :($(Lambda)($(uneval(x.args)), $(uneval(x.body)))) # implementation 2
# in particular, why does implementation 1, when called in a macro, produce a fully-qualified reference to `Lambda`?
# and what happens if `Lambda` is not available in the scope of the macro definition?

#= implementation 1
julia> dump(@macroexpand FixArgs.New.@xquote (x, y) -> x + y)
Expr
  head: Symbol call
  args: Array{Any}((3,))
    1: GlobalRef
      mod: Module FixArgs.New
      name: Symbol Lambda
[...]
=#

#= implementation 2
julia> dump(@macroexpand FixArgs.New.@xquote (x, y) -> x + y)
Expr
  head: Symbol call
  args: Array{Any}((3,))
    1: UnionAll
      var: TypeVar
        name: Symbol A
        lb: Union{}
        ub: Any
      body: UnionAll
        var: TypeVar
          name: Symbol B
          lb: Union{}
          ub: Any
        body: Lambda{A, B} <: Any
          args::A
          body::B
[...]
=#
uneval(x::Call) = :(Call($(uneval(x.f)), $(uneval(x.args))))
