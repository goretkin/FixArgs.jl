#=
type aliases
=#

const FixNew{ARGS_IN, F, ARGS_CALL} = Lambda{ARGS_IN, Call{F, ARGS_CALL}}

# define constructor consistent with type alias
function FixNew(args_in, f, args_call)
    Lambda(args_in, Call(f, args_call))
end

_type_from_pos_type(T) = FrankenTuple{T, (), Tuple{}}
_val_from_pos_val(t) = FrankenTuple(t)

# TODO will be `Some{T}`, not `T`, on the rhs
const Fix1{F, T} = FixNew{typeof(Arity(1)), Some{F}, _type_from_pos_type(Tuple{Some{T}, typeof(ArgPos(1))})}
const Fix2{F, T} = FixNew{typeof(Arity(1)), Some{F}, _type_from_pos_type(Tuple{typeof(ArgPos(1)), Some{T}})}
# define constructor consistent with type alias
function Fix1(f, x)
    FixNew(Arity(1), Some(f), _val_from_pos_val((Some(x), ArgPos(1))))
end
function Fix2(f, x)
    FixNew(Arity(1), Some(f), _val_from_pos_val((ArgPos(1), Some(x))))
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

function xescape(x, annotation::Symbol)
    annotation === :S && return Val(x)
    error("unexpected annotation: $(annotation)")
end

""""
Should parse these
`[:((a::b)::c), :(a::b), :(a::::c), :a, :(::b::c), :(::b), :(::::c)]`
with pattern of `nothing`s, if padded on the right to be 3-tuples, counting in binary from 7 to 1
"""
function _parse_double_colon(ex)
    # the splatting on the recursive calls makes different groupings produce the same result:
    # e.g. `:((a::b)::c)` and `:(a::(b::c))`
    if Meta.isexpr(ex, :(::))
        if length(ex.args) == 1
            return (nothing, _parse_double_colon(ex.args[1])...)
        elseif length(ex.args) == 2
            return (_parse_double_colon(ex.args[1])..., _parse_double_colon(ex.args[2])...)
        end
    else
        return (Some(ex), )
    end
end

function xescape_expr(ex)
    p = _parse_double_colon(ex)
    if (!isnothing).(p) == (true, false, true)
        # expression of form `value::::annotation`
        return Expr(:call, xescape, something(p[1]), QuoteNode(something(p[3])))
    end
    Expr(:call, xescape, ex)
end

function escape_all_but(ex, apply = esc ∘ xescape_expr)
    _escape_all_but(ex) = escape_all_but(ex, apply)

    ex isa Symbol && return apply(ex)
    ex isa QuoteNode && return apply(ex)
    ex isa BoundSymbol && return ex
    ex isa Expr || return apply(ex)

    # don't escape any formal parameters
    ex.head === :call && return Expr(ex.head, map(_escape_all_but, ex.args)...)
    ex.head === :-> && return Expr(ex.head, ex.args[1], map(_escape_all_but, ex.args[2:end])...)
    ex.head === :kw && return Expr(ex.head, ex.args[1], map(_escape_all_but, ex.args[2:end])...)
    ex.head === :$ && return apply(only(ex.args))
    return apply(ex) # to escape e.g. `Base.sqrt`
end

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
    uneval(escape_all_but(ex, esc))
end

function _xquote(ex)
    # does escaping, so the `value` produced here only makes sense in the context of a macro that does `uneval(value)`

    # TODO escape any e.g. `BoundSymbol` before passing to `designate_bound_arguments`.
    # otherwise cannot distinguish between original `BoundSymbol` and output of `designate_bound_arguments`
    # Then these escaped `BoundSymbol`s should not be touched by `normalize_bound_vars`
    ex1 = clean_expr(ex)
    ex2 = designate_bound_arguments(ex1)

    # escape everything that isn't a bound variable, so that they are evaluated in the macro call context.
    # unquoted `Symbol` comes to represent free variables in the λ calculus (as does e.g. `:(Base.sqrt)`)
    # `BoundSymbol{::Symbol}` comes to represent bound variables in the λ calculus
    ex3 = escape_all_but(ex2)
    ex4 = normalize_bound_vars(ex3)
    value = lc_expr(TypedExpr(ex4))
    return value
end

macro xquote(ex)
    value = _xquote(ex)
    uneval(value) # note: uneval handles `Expr(:escape, ...)` specially.
end

# old tests and old type equivocate between e.g. `1` and `Some(1)`
# macro already does escaping, so arguments `args` here are already `xescape`d.
fix_some(s::Some) = s
fix_some(x::Nothing) = x
fix_some(x) = Some(x)

# this pattern of splitting the recursion into two functions allows for handling the empty base case uniformly.
# I wanted to avoid a separate definition just to do type-inferred `count(isnothing, ::Tuple)`
# so the recursion "bubbles up" the final `state`
_assemble(wrap, state, args::Tuple{}) = ((), state)
_assemble(wrap, state, args) = __assemble(wrap, state, first(args), Base.tail(args))

# it is necessary for `state` to be "represented in the type domain" for inference
function __assemble(wrap, state::Val{arg_i}, arg1::Nothing, arg_rest::Tuple) where arg_i
    (rest, state′) = _assemble(wrap, Val{arg_i + 1}(), arg_rest)
    ((ArgPos(arg_i), rest...), state′)
end

function __assemble(wrap, state, arg1, arg_rest::Tuple)
    (rest, state′) = _assemble(wrap, state, arg_rest)
    ((wrap(arg1), rest...), state′)
end

assemble(args, wrap=Some) = _assemble(wrap, Val(1), args)

function fix(f, args...; kwargs...)
    # With the old model, any extra kwargs could be passed only into one function.
    # Not so anymore.
    # to get some of the uses of `fix` working, need to introduce a `Splat` representation

    _get(::Val{i}) where {i} = i - 1

    (_pos_call_args, _arity) = assemble(args, fix_some)
    call_args = FrankenTuple(_pos_call_args, map(Some, kwargs.data))

    Lambda(
        Arity{_get(_arity), Nothing}(),
        Call(
            Some(f),
            call_args
        )
    )
end


# roughly equivalent to xescape_arg
function escape_arg(ex)
    if Meta.isexpr(ex, :kw)
        ex
    elseif Meta.isexpr(ex, Symbol("..."))
        :(map(Some, $(ex.args[1]))...)      # TODO also `SomeUnlessFix` here?
    elseif ex == :_
        nothing
    elseif startswith(string(ex), "_")
        p = parse(Int, string(ex)[2:end])
        ArgPos{p}()
    else
        Expr(:call, xescape, ex)
    end
end

"""
`@fix f(_,b)` macroexpands to `fix(f, nothing, Some(b))`

"""
macro fix(call)
    if !Meta.isexpr(call, :call)
        error("Argument must be a function call expression, got $call")
    end
    f = call.args[1]
    args = call.args[2:end]
    has_parameters = !isempty(args) && Meta.isexpr(args[1], :parameters)
    ret = if has_parameters
        parameters = args[1]
        Expr(:call, fix, parameters, f, escape_arg.(args[2:end])...)
    else
        Expr(:call, fix, f, escape_arg.(args)...)
    end
    esc(ret)
end