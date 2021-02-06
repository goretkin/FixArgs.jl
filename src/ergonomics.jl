#=
type aliases
=#

const FixNew{ARGS_IN, F, ARGS_CALL} = Lambda{ARGS_IN, Call{F, ARGS_CALL}}
# define constructor consistent with type alias
function FixNew(args_in, f, args_call)
    Lambda(args_in, Call(f, args_call))
end

# TODO will be `Some{T}`, not `T`, on the rhs
const Fix1{F, T} = FixNew{typeof(Arity(1)), Some{F}, Tuple{Some{T}, typeof(ArgPos(1))}}
const Fix2{F, T} = FixNew{typeof(Arity(1)), Some{F}, Tuple{typeof(ArgPos(1)), Some{T}}}
# define constructor consistent with type alias
function Fix1(f, x)
    FixNew(Arity(1), Some(f), (Some(x), ArgPos(1)))
end
function Fix2(f, x)
    FixNew(Arity(1), Some(f), (ArgPos(1), Some(x)))
end


#=
`show` methods
=#
function _show_arg_pos(io::IO, i, p)
    print(io, "arg_pos($i, $p)")
end

unwrap_ParentScope(x::ArgPos, p=0) = (x, p)
unwrap_ParentScope(x::ParentScope, p=0) = unwrap_ParentScope(x._, p + 1)

function Base.show(io::IO, a::Union{ParentScope, ArgPos{i} where i})
    _get(::ArgPos{i}) where {i} = i
    (_a, p) = unwrap_ParentScope(a)
    _show_arg_pos(io, _get(_a), p)
end

Base.show(io::IO, x::Lambda) = Show._show_without_type_parameters(io, x)
Base.show(io::IO, x::Call) = Show._show_without_type_parameters(io, x)

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

# show consistent with constructor that is consistent with type alias

function Base.show(io::IO, x::Fix1)
    print(io, "Fix1")
    print(io, "(")
    show(io, something(x.body.f))
    print(io, ",")
    show(io, something(x.body.args[1]))
    print(io, ")")
end

function Base.show(io::IO, x::Fix2)
    print(io, "Fix2")
    print(io, "(")
    show(io, something(x.body.f))
    print(io, ",")
    show(io, something(x.body.args[2]))
    print(io, ")")
end


#=
macros
=#

# to enable static data (data baked into the type)
# and enable all values, e.g. `ArgPos(1)`, to be bound.
# in macro invocation `xescape` everything that will be evaluated at macro usage scope
xescape(x) = Some(x)

# exceptions
xescape(x::Val) = x

# `Some` is used to escape the exceptions, do not wrap again
xescape(x::Some{<:Val}) = x

function xescape_expr(ex)
    Expr(:call, xescape, ex)
end

# `escape_all_but_old` is supporting some unit tests.
escape_all_but_old(ex) = apply_once(do_escape, esc, ex)
escape_all_but(ex) = apply_once(do_escape, x -> esc(xescape_expr(x)), ex)

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
macro quote_some(ex)
    uneval(escape_all_but_old(ex))
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
    value = lc_expr(TypedExpr(ex4))
    uneval(value) # note: uneval handles `Expr(:escape, ...)` specially.
end
