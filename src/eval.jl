"""
terms are evaluated with respect to a `Context`
A `Context` is an associations between bound variables and values, and they may be nested (via the `parent` field).
"""
struct Context{E, P}
    this::E
    parent::P
end

# TODO: other evaluation schemes to take e.g. `@xquote () -> 1 + 2` to `@xquote () -> 3`

# TODO clean up base case to have just one of these two
xeval(a::ArgPos{i}, ctx::Context{Nothing, P}) where {i, P} = a
xeval(a::ArgPos{i}, ctx::Nothing) where {i} = a

# also just one of these two.
xeval(a::Some, ctx::Context) = something(a)
xeval(a::Some, ctx::Nothing=nothing) = something(a)

xeval(a::Val{T}, ctx) where T = T

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

# See https://github.com/ararslan/FrankenTuples.jl/issues/2#issuecomment-1170322427
# I want `map(f, ::FrankenTuple)` to behave like `map(f, ::NamedTuple)`
# so I define `_map` that does.
# If `FrankenTuple` includes an updated definition of `map` with the given property, then it can be removed.
_map(args...) = map(args...)

# Copy from https://github.com/goretkin/FrankenTuples.jl/commit/ebc3a71837b6272d5dbb09657527757cc39170cc
# NOTE: this method signature makes sure we don't define map(f)
function _map(f, ft::FrankenTuple, fts::FrankenTuple...)
    t = map(f, Tuple(ft), map(Tuple, fts)...)
    nt = map(f, NamedTuple(ft), map(NamedTuple, fts)...)
    FrankenTuple(t, nt)
end


# kwargs should work with Base.map(f, ::FrankenTuple)
# TODO: define `Splat{T}` to represent e.g. `@xquote x -> foo(x...)`
_xeval_call_args(c::Call, ctx::Context) = _map(x -> xeval(x, ctx), c.args)

function xeval(c::Call, ctx::Context)
    #println("xeval(::Call, ::Context) : $(c)")
    args_eval = _xeval_call_args(c, ctx)
    f = xeval(c.f, ctx)
    _xapply(f, args_eval)
end

xeval_esc(x::ArgPos, ctx) = x # not evaluating these
xeval_esc(x::ParentScope, ctx) = xeval(x, ctx)
xeval_esc(x::Call, ctx) = xeval(x, ctx)
xeval_esc(x, ctx) = xeval(x, ctx)

some_esc(old, new) = Some(new)

# do not wrap in `Some`
some_esc(old::ArgPos, new::ArgPos) = new
some_esc(old::ParentScope, new::ParentScope) = new
some_esc(old::Call, new::Call) = new

_xeval_call_args_esc(c::Call, ctx::Context) = _map(x -> some_esc(x, xeval_esc(x, ctx)), c.args)   # TODO kwargs

function xeval(c::Call, ctx::Context{Nothing, P}) where P
    #println("xeval(::Call, ::Context{Nothing, ...}) : $(c)")
    # this was invoked by `xeval(some_lambda::Lambda, ...)`
    # which means we are not going to call `c.f`
    # since the `Call` could contain unevaluated terms (those corresponding to the formal arguments of `some_lambda`)
    # TODO evaluate if possible? explore different evaluation schemes.
    # TODO do not special-case this behavior, instead just detect unevaluated terms.
    Call(
        some_esc(c.f, xeval_esc(c.f, ctx)),
        _xeval_call_args_esc(c, ctx)
    )
end

"""
evaluate a Lambda-Call expression

Currently only works on [`Call`](@ref) expressions.
"""
xeval(c::Call) = xeval(c, Context(Context(nothing, nothing), nothing))

function check_arity(f::Lambda{Arity{P, NoKeywordArguments}, B}, args) where {P, B}
    (P == length(args)) && return
    error("lambda of arity $P cannot apply to $(length(args)) arguments")
end

# for now, `Context` is all positional.
# but this could be extended so that `xeval` may work more generally
# e.g. with default arguments
_ctx_this(args_formal::Arity, args_actual) = args_actual

"""
apply a [`Lambda`](@ref) expression to arguments.
"""
function xapply(f::Lambda, args, ctx_parent=nothing)
    check_arity(f, args)
    xeval(f.body, Context(_ctx_this(f.args, args), ctx_parent))
end

function _xapply(f, args::Tuple)
    f(args...)
end

function _xapply(f, args::FrankenTuple)
    FrankenTuples.ftcall(f, args)
end

(f::Lambda)(args...) = xapply(f, args)

# TODO kwargs at call site
# e.g.
# (f::Lambda)(args..., kwargs...) = xapply(f, FrankenTuple(args, kwargs.data))
