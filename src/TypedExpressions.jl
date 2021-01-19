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
struct TypedExpr{H, A}
    head::H
    args::A
end

function _typed(expr::Expr)
    expr.head == :escape && return expr
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

_Union() = Union{}
_Union(x) = Union{x}
_Union(a, b) = Union{a, b}
_Union(x...) = reduce(_Union, x)

KeywordArgType(kwarg_names...) = _Union(sort(collect(kwarg_names))...)

_typed1(expr::TypedExpr{Val{:->}, Tuple{A, B}}) where {A, B} = Lambda(_typed1(expr.args[1]), _typed1(expr.args[2]))
_typed1(expr::TypedExpr{Val{:call}, X}) where {X} = Call(expr.args[1], expr.args[2:end]) # TODO handle TypedExpr with kwargs
_typed1(expr::TypedExpr{Val{:tuple}, X}) where {X} = expr.args
_typed1(x) = x

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

_get(::Val{x}) where {x} = x

# TODO wrap all initial `BoundSymbol` in some Escaping mechanism, and bail out on relabeling
_relabeler(x) = if x.referent_depth - x.antecedent_depth == 0
    x.sym
else
    BoundSymbol(x.sym)
end

designate_bound_arguments(ex) = relabel_args(x -> x isa Symbol, _relabeler, ex)
escape_all_symbols(ex) = MacroTools.postwalk(x -> x isa Symbol ? esc(x) : x, ex)
ArgSymbol_to_Symbol(ex) = MacroTools.postwalk(x -> x isa ArgSymbol ? esc(x._) : x, ex)
escape_all_Val_symbols(ex) = MacroTools.postwalk(x -> x isa Val ? esc(_get(x)) : x, ex)

function quote1(ex)
    ex = clean_ex(ex) # just for debugging
    marked_bound_vars = designate_bound_arguments(ex)
    # all remaining `Symbol`s correspond to "free variables", and should be escaped so that they are evaluated in the macro call context.
    free_esc = escape_all_symbols(marked_bound_vars)
    @show esc(:y)
    return free_esc
    # return ArgSymbol_to_Symbol(free_esc)
end

macro quote1(ex)
    quote1(ex)
end

macro quote2(ex)
    # ex1 = @quote1 ex
    ex0 = designate_bound_arguments(ex)
    # ex1 = escape_all_symbols(ex0)
    ex1 = ex0
    # println(ex1)
    val = all_typed(ex1)
    ex2 = quote $(esc(val)) end
    ex3 = escape_all_Val_symbols(ex2)
    return ex2
end
end

macro _test1(ex)
    quote
        ($ex, $(esc(ex)))
    end
end
using .TypedExpressions: EscVal, all_typed
_ex_1 = :(x -> ==(x, 0))
_ex_2 = :(x -> $(==)(x, 0))
_ex_3 = :(x -> $(==)(x, :zero))
_ex_4 = :(x -> $(==)(x, $(Val(0))))
_ex_5 = :(x -> $(==)(x, $(EscVal{Val(0)}())))

ex = all_typed(_ex_2)

using Test
if VERSION >= v"1.6-"
    # test alias printing
    # @test string(typeof(ex)) == "FixNew{Tuple{Val{:x}}, typeof(==), Tuple{Val{:x}, Int64}}"
end