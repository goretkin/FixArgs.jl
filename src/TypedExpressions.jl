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
module TypedExpressions

include("parse.jl")
include("expr.jl")
include("show.jl")

struct TypedExpr{H, A}
    head::H
    args::A
end

# TODO define something like the following to mirror `Expr`
# TypedExpr(head, args...) = TypedExpr(head, args)

function _typed(expr::Expr)
    expr.head === :escape && return expr
    TypedExpr(
        _typed(expr.head),
        _typed(expr.args)
    )
end

"""
`Val{::Symbol}` comes to represent free variables in the λ calculus
`BoundVal{::Symbol}` comes to represent bound variables in the λ calculus
"""
struct BoundVal{T}
end
struct EscVal{T}
end

_typed(args::Vector) = tuple(map(_typed, args)...)
_typed(sym::Symbol) = Val(sym)
_typed(x::BoundSymbol) = x
_typed(x::ArgSymbol) = x
_typed(x) = x

#=
# pass on anything that is already evaluated
_typed(x) = x

# if it was an evaluated `Val`, etc., then escape it to distinguish it from having originated with a ::Symbol
_typed(x::Val) = EscVal{typeof(x)}()
_typed(x::BoundVal) = EscVal{typeof(x)}()
_typed(x::EscVal) = EscVal{typeof(x)}()

# because Symbol is already wrapped above, we can unquote `QuoteNode` of `Symbol`.
# e.g. ``:(:x)`` to ``:x`
# TODO perhaps not just `Symbol`?
_typed(x::QuoteNode) = x.value isa Symbol ? x.value : x
=#

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

struct Args{P, KW}
end

struct Lambda{A, B}
    args::A
    body::B
end

struct Call{F, A}
    f::F
    args::A
end

uneval(x::Lambda) = :(Lambda($(uneval(x.args)), $(uneval(x.body))))
uneval(x::Call) = :(Call($(uneval(x.f)), $(uneval(x.args))))

Base.show(io::IO, x::Lambda) = Show._show_without_type_parameters(io, x)
Base.show(io::IO, x::Call) = Show._show_without_type_parameters(io, x)

#=
# Try to represent an unordered collection as a type, to represent keyword arguments.
_Union() = Union{}
_Union(x) = Union{x}
_Union(a, b) = Union{a, b}
_Union(x...) = reduce(_Union, x)

KeywordArgType(kwarg_names...) = _Union(sort(collect(kwarg_names))...)
=#
_typed1(expr::TypedExpr{Val{:->}, Tuple{A, B}}) where {A, B} = Lambda(_typed1(expr.args[1]), _typed1(expr.args[2]))
_typed1(expr::TypedExpr{Val{:call}, X}) where {X} = Call(_typed1(expr.args[1]), map(_typed1, expr.args[2:end])) # TODO handle TypedExpr with kwargs
_typed1(expr::TypedExpr{Val{:tuple}, X}) where {X} = map(_typed1, expr.args)
function _typed1(expr::Expr)
    expr.head === :escape && return expr
    error("_typed1(::Expr) unexpected head: $(expr)")
end

_typed1(x::BoundSymbol) = x
_typed1(x::ArgSymbol) = x
_typed1(x) = x

# _typed1(x) = x

using MacroTools: MacroTools, striplines, flatten

is_lambda_1_arg(ex::Expr) = (ex.head == :->) && (ex.args[1] isa Symbol) # TODO or check that it's not a ex::Expr with `ex.head === :tuple`
is_lambda_1_arg(x) = false

function _normalize_lambda_1_arg(ex)
    is_lambda_1_arg(ex) || return ex
    arg = ex.args[1]
    body = ex.args[2]
    return :(($(arg), ) -> $(body))
end

"""normalize `:(x -> body)` into  `:((x,) -> body`)"""
normalize_lambda_1_arg(ex) = MacroTools.prewalk(_normalize_lambda_1_arg, ex)

# other order doesn't work. I suppose `striplines` introduces blocks
clean_ex(ex) = flatten(striplines(normalize_lambda_1_arg(ex)))



all_typed(ex) = begin
    #println("all_typed")
    #dump(ex)
    _typed1(_typed(clean_ex(ex)))
end

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

_get(::Val{x}) where {x} = x

# TODO wrap all initial `BoundSymbol` in some Escaping mechanism, and bail out on relabeling
_relabeler(x) = if x.referent_depth - x.antecedent_depth == 0
    ArgSymbol(x.sym)
else
    BoundSymbol(x.sym)
end

designate_bound_arguments(ex) = relabel_args(x -> x isa Symbol, _relabeler, ex)
escape_all_symbols(ex) = MacroTools.postwalk(x -> x isa Symbol ? esc(x) : x, ex)
ArgSymbol_to_Symbol(ex) = MacroTools.postwalk(x -> x isa ArgSymbol ? esc(x._) : x, ex)
escape_all_Val_symbols(ex) = MacroTools.postwalk(x -> x isa Val ? esc(_get(x)) : x, ex)

macro xquote(ex)
    # TODO escape any e.g. `BoundSymbol` before passing to `designate_bound_arguments`.
    ex1 = clean_ex(ex)
    ex2 = designate_bound_arguments(ex1)
    # escape everything that isn't a bound variable, so that they are evaluated in the macro call context.
    ex3 = escape_all_but(ex2)
    uneval(all_typed(ex3))
end
end
