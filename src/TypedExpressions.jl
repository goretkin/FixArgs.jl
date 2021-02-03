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

"""
Note that `Expr` and `TypedExpr` are constructed slightly differently.
Each argument of an `Expr` is an argument to `Expr`, whereas
all arguments of a `TypedExpr` are passed as one argument (a tuple) to `TypedExpr`

e.g.

`Expr(:call, +, 1, 2)` corresponds to
`TypedExpr(Val{:call}(), (+, 1, 2))`
"""
struct TypedExpr{H, A}
    head::H
    args::A
end

function TypedExpr(expr::Expr)
    TypedExpr(
        typed_expr(expr.head),
        typed_expr(expr.args)
    )
end

typed_expr(args::Vector) = tuple(map(typed_expr, args)...)
typed_expr(sym::Symbol) = Val(sym)
typed_expr(expr::Expr) = TypedExpr(expr)
typed_expr(x) = x

function inv_typed_expr(expr::TypedExpr)
    Expr(
        inv_typed_expr(expr.head),
        inv_typed_expr(expr.args)...
    )
end

inv_typed_expr(args::Tuple) = map(inv_typed_expr, [args...])
inv_typed_expr(val::Val{sym}) where sym = sym
inv_typed_expr(x) = x

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

include("types.jl")

function _show_arg_pos(io::IO, i, p)
    print(io, "arg_pos($i, $p)")
end

unwrap_ParentScope(x::ArgPos, p=0) = (x, p)
unwrap_ParentScope(x::ParentScope, p=0) = unwrap_ParentScope(x._, p + 1)

_get(::ArgPos{i}) where {i} = i

function Base.show(io::IO, a::Union{ParentScope, ArgPos{i} where i})
    (_a, p) = unwrap_ParentScope(a)
    _show_arg_pos(io, _get(_a), p)
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

Base.show(io::IO, x::Lambda) = Show._show_without_type_parameters(io, x)
Base.show(io::IO, x::Call) = Show._show_without_type_parameters(io, x)

lc_expr(expr::TypedExpr{Val{:->}, Tuple{A, B}}) where {A, B} = Lambda(lc_expr(expr.args[1]), lc_expr(expr.args[2]))
lc_expr(expr::TypedExpr{Val{:call}, X}) where {X} = Call(lc_expr(expr.args[1]), map(lc_expr, expr.args[2:end])) # TODO handle TypedExpr with kwargs
lc_expr(expr::TypedExpr{Val{:tuple}, X}) where {X} = map(lc_expr, expr.args)
lc_expr(expr::TypedExpr{Val{:escape}, X}) where {X} = inv_typed_expr(expr)

"""
Lambda-Call expression
"""
lc_expr(x) = x

const FixNew{ARGS_IN, F, ARGS_CALL} = Lambda{ARGS_IN, Call{F, ARGS_CALL}}

# define constructor consistent with type alias
function FixNew(args_in, f, args_call)
    Lambda(args_in, Call(f, args_call))
end

# show consistent with constructor that is consistent with type alias
function Base.show(io::IO, x::FixNew)
    print(io, "FixNew")
    print(io, "(")
    show(io, x.args)
    print(io, ",")
    show(io, x.body.f)
    print(io, ",")
    show(io, x.body.args)
    print(io, ")")
end

# TODO will be `Some{T}`, not `T`, on the rhs
const Fix1{F, T} = FixNew{typeof(Arity(1)), F, Tuple{T, typeof(ArgPos(1))}}
const Fix2{F, T} = FixNew{typeof(Arity(1)), F, Tuple{typeof(ArgPos(1)), T}}

# define constructor consistent with type alias
function Fix1(f, x)
    FixNew(Arity(1), f, (x, ArgPos(1)))
end

function Fix2(f, x)
    FixNew(Arity(1), f, (ArgPos(1), x))
end

# show consistent with constructor that is consistent with type alias

function Base.show(io::IO, x::Fix1)
    print(io, "Fix1")
    print(io, "(")
    show(io, x.body.f)
    print(io, ",")
    show(io, x.body.args[1])
    print(io, ")")
end

function Base.show(io::IO, x::Fix2)
    print(io, "Fix2")
    print(io, "(")
    show(io, x.body.f)
    print(io, ",")
    show(io, x.body.args[2])
    print(io, ")")
end

_get(::Val{x}) where {x} = x

designate_bound_arguments(ex) = relabel_args(x -> x isa Symbol, x -> BoundSymbol(x.sym), ex)

function normalize_bound_vars(ex)
    placeholder_symbol = :_

    # relabel all `BoundSymbol`s:
    # key: head -> body
    # those in bodies get renamed by `arg_pos`
    # those in heads get renamed to a placeholder
    function relabeler(x)
        (i, p) = (x.arg_i, x.referent_depth - x.antecedent_depth)
        p == 0 && return BoundSymbol(placeholder_symbol)
        return arg_pos(i, p)
    end

    ex1 = relabel_args(
        x -> x isa BoundSymbol,
        relabeler,
    ex)

    # replace all heads, which should all be placeholders with `Arity`
    # TODO ensure all heads were replaced (any heads without all placeholders is an error at this point)
    function check(ex)
        ex isa Expr && ex.head === :tuple && all(==(BoundSymbol(placeholder_symbol)), ex.args)
    end

    function apply(ex)
        n = length(ex.args)
        return Arity(n)
    end

    return apply_once(check, apply, ex1)
end

macro xquote(ex)
    # TODO escape any e.g. `BoundSymbol` before passing to `designate_bound_arguments`.
    # otherwise cannot distinguish between original `BoundSymbol` and output of `designate_bound_arguments`
    # Then these escaped `BoundSymbol`s should not be touched by `normalize_bound_vars`
    ex1 = clean_expr(ex)
    ex2 = designate_bound_arguments(ex1)

    # escape everything that isn't a bound variable, so that they are evaluated in the macro call context.
    # unquoted `Symbol` comes to represent free variables in the λ calculus (as does e.g. `:(Base.sqrt)`, see `do_escape`)
    # `BoundSymbol{::Symbol}` comes to represent bound variables in the λ calculus
    ex3 = escape_all_but(ex2)
    ex4 = normalize_bound_vars(ex3)
    val = lc_expr(TypedExpr(ex4))
    uneval(val) # note: uneval handles `Expr(:escape, ...)` specially.
end

include("eval.jl")

end
