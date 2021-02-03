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

function typed_expr(expr::Expr)
    TypedExpr(
        typed_expr(expr.head),
        typed_expr(expr.args)
    )
end

typed_expr(args::Vector) = tuple(map(typed_expr, args)...)
typed_expr(sym::Symbol) = Val(sym)
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

struct Arity{P, KW}
end

# TODO choose a representation for keyword arguments
const NoKeywordArguments = Nothing
function Arity(p_arity, kw_arity = NoKeywordArguments)
    return Arity{p_arity, NoKeywordArguments}()
end
struct ArgPos{N}
end

ArgPos(i) = ArgPos{i}()

placeholder_symbol = :_

function arg_pos(i, p)
    p >=0 || error()
    p == 0 && return BoundSymbol(placeholder_symbol)
    p == 1 && return ArgPos(i)
    ParentScope(arg_pos(i, p - 1))
end
struct ParentScope{T}
    _::T
end

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

struct Lambda{A, B}
    args::A
    body::B
end

struct Call{F, A}
    f::F
    args::A
end

# TODO investigate difference between these two, (and in general, all `uneval`s) with respect to returning from a macro:
uneval(x::Lambda) = :(Lambda($(uneval(x.args)), $(uneval(x.body))))     # implementation 1
# uneval(x::Lambda) = :($(Lambda)($(uneval(x.args)), $(uneval(x.body)))) # implementation 2
# in particular, why does implementation 1, when called in a macro, produce a fully-qualified reference to `Lambda`?
# and what happens if `Lambda` is not available in the scope of the macro definition?

#= implementation 1
julia> dump(@macroexpand FixArgs.TypedExpressions.@xquote (x, y) -> x + y)
Expr
  head: Symbol call
  args: Array{Any}((3,))
    1: GlobalRef
      mod: Module FixArgs.TypedExpressions
      name: Symbol Lambda
[...]
=#

#= implementation 2
julia> dump(@macroexpand FixArgs.TypedExpressions.@xquote (x, y) -> x + y)
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

_typed1(expr::TypedExpr{Val{:->}, Tuple{A, B}}) where {A, B} = Lambda(_typed1(expr.args[1]), _typed1(expr.args[2]))
_typed1(expr::TypedExpr{Val{:call}, X}) where {X} = Call(_typed1(expr.args[1]), map(_typed1, expr.args[2:end])) # TODO handle TypedExpr with kwargs
_typed1(expr::TypedExpr{Val{:tuple}, X}) where {X} = map(_typed1, expr.args)
_typed1(expr::TypedExpr{Val{:escape}, X}) where {X} = inv_typed_expr(expr)

_typed1(x::BoundSymbol) = x
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
    _typed1(typed_expr(clean_ex(ex)))
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
    ex1 = relabel_args(
        x -> x isa BoundSymbol,
        x -> arg_pos(x.arg_i, x.referent_depth - x.antecedent_depth),
    ex)

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
    ex1 = clean_ex(ex)
    ex2 = designate_bound_arguments(ex1)

    # escape everything that isn't a bound variable, so that they are evaluated in the macro call context.
    # unquoted `Symbol` comes to represent free variables in the λ calculus (as does e.g. `:(Base.sqrt)`, see `do_escape`)
    # `BoundSymbol{::Symbol}` comes to represent bound variables in the λ calculus
    ex3 = escape_all_but(ex2)
    ex4 = normalize_bound_vars(ex3)
    val = all_typed(ex4)
    uneval(val) # note: uneval handles `Expr(:escape, ...)` specially.
end

struct Context{E, P}
    this::E
    parent::P
end

# TODO clean up base case to have just one of these two
xeval(a::ArgPos{i}, ctx::Context{Nothing, P}) where {i, P} = a
xeval(a::ArgPos{i}, ctx::Nothing) where {i} = a

# also just one of these two. Also TODO: define only on `Some`
xeval(a, ctx::Context) = a
xeval(a, ctx::Nothing) = a

# TODO:
#xeval(a::Val{T}, ctx::Union{Nothing, <:Context}) = T

_wrap_arg(x::ArgPos) = ParentScope(x)
_wrap_arg(x) = x
xeval(a::ArgPos{i}, ctx::Context{T, P}) where {i, T, P} = ctx.this[i]
xeval(a::ParentScope{A}, ctx::Context) where {A} = _wrap_arg(xeval(a._, ctx.parent))


function xeval(c::Lambda, ctx::Context)
    #println("xeval(::Lambda, ::Context) : $(c)")
    Lambda(
        c.args,
        xeval(c.body, Context(nothing, ctx))
    )
end

_xeval_call_args(c::Call, ctx::Context) = map(x -> xeval(x, ctx), c.args)           # TODO kwargs

# Alternative to this definition involves using `Some` to wrap the f field as well, so that plain `xeval` can be used
# (after `Some` is implemented in this branch)
_xeval_call_f(f, ctx) = f
_xeval_call_f(f::Call, ctx) = xeval(f, ctx)

function xeval(c::Call, ctx::Context)
    #println("xeval(::Call, ::Context) : $(c)")
    args_eval = _xeval_call_args(c, ctx)
    f = _xeval_call_f(c.f, ctx)
    f(args_eval...)    # TODO kwargs
end

xeval_esc(x, ctx) = x # specifically, pass through `ArgPos`
xeval_esc(x::ParentScope, ctx) = xeval(x, ctx)
xeval_esc(x::Call, ctx) = xeval(x, ctx)
_xeval_call_args_esc(c::Call, ctx::Context) = map(x -> xeval_esc(x, ctx), c.args)   # TODO kwargs

function xeval(c::Call, ctx::Context{Nothing, P}) where P
    #println("xeval(::Call, ::Context{Nothing, ...}) : $(c)")
    # this was invoked by `xeval(::Lambda, ...)`
    # which means we are not going to call `c.f`
    Call(
        xeval_esc(c.f, ctx),
        _xeval_call_args_esc(c, ctx)
    )
end

function check_arity(f::Lambda{Arity{P, NoKeywordArguments}, B}, args) where {P, B}
    (P == length(args)) && return
    error("lambda of arity $P cannot apply to $(length(args)) arguments")
end

_ctx_this(args_formal, args_actual) = args_actual

function xapply(f::Lambda, args, ctx_parent=nothing)
    check_arity(f, args)
    xeval(f.body, Context(_ctx_this(f.args, args), ctx_parent))
end

(f::Lambda)(args...) = xapply(f, args)
end
