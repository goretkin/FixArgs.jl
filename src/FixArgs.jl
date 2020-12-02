module FixArgs

using Base: tail
export Fix, @fix, fix, @FixT

"""
Represent a function call, with partially bound arguments.
"""
struct Fix{F, A, K} <: Function
    f::F
    args::A
    kw::K
end

Fix(::Type{T}, a, k) where {T} = Fix{Type{T}, typeof(a), typeof(k)}(T, a, k)

function (c::Fix)(args...; kw...)
    c.f(interleave(c.args, args)...; c.kw..., kw...)
end

"""
Return a `Tuple` that interleaves `args` into the `nothing` slots of `slots`.

```jldoctest
FixArgs.interleave((:a, nothing, :c, nothing), (12, 34))

# output

(:a, 12, :c, 34)
```

Use `Some` to escape `nothing`

```jldoctest
FixArgs.interleave((:a, Some(nothing), :c, nothing), (34,))

# output

(:a, nothing, :c, 34)
```
"""
interleave(bind, args) = _interleave(first(bind), tail(bind), args)
interleave(bind::Tuple{}, args::Tuple{}) = ()
interleave(bind::Tuple{}, args::Tuple) = error("more args than positions")

# `nothing` indicates a position to be bound
_interleave(firstbind::Nothing, tailbind::Tuple, args::Tuple) = (
  first(args), interleave(tailbind, tail(args))...)

# allow escaping of e.g. `nothing`
_interleave(firstbind::Some{T}, tailbind::Tuple, args::Tuple) where T = (
  something(firstbind), interleave(tailbind, args)...)

_interleave(firstbind::T, tailbind::Tuple, args::Tuple) where T = (
  firstbind, interleave(tailbind, args)...)

# recursively evaluate unescaped `Fix`
_interleave(firstbind::Fix, tailbind::Tuple, args::Tuple) where T = (
    firstbind((first(args)::Tuple)...), interleave(tailbind, tail(args))...)

"""
    `fix(f, a, b)`
    `fix(f, args...; kw...)`

The `fix` function partially evaluates `f` by fix some of its arguments.
Positional arguments of `f` that should not be bound are indicated by passing `nothing`
to `fix` at the respective position.
```jldoctest
julia> using FixArgs: fix

julia> b = fix(+, 1, 2); # no nothing, all arguments bound

julia> b()
3

julia> b = fix(*, "hello", nothing); # only first argument bound

julia> b(", world")
"hello, world"

julia> b = fix(=>, nothing, 1); # second argument bound

julia> b("one")
"one" => 1

julia> b = fix(isapprox, nothing, nothing, atol=100); # only atol keyword bound

julia> b(10, 20)
true

julia> b(10, 20, atol=1) # keywords can be reassigned on the fly
false
```
"""
fix(f, args...; kw...) = Fix(f, args, kw.data)

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

SomeUnlessFix(x) = Some(x)          # if macro invocation contains a "bare" argument, wrap it
SomeUnlessFix(x::Fix) = x           # unless it is `Fix`
SomeUnlessFix(x::Some{<:Fix}) = x   # but if `Some` is used to escape this behavior, then do not wrap it again

function escape_arg(ex)
    if Meta.isexpr(ex, :kw)
        ex
    elseif Meta.isexpr(ex, Symbol("..."))
        :(map(Some, $(ex.args[1]))...)      # TODO also `SomeUnlessFix` here?
    elseif ex == :_
        nothing
    else
        Expr(:call, SomeUnlessFix, ex)
    end
end

function parse_type_spec(ex)
    Meta.isexpr(ex, :(::), 1) || throw(Base.Meta.ParseError("expected a `::T`, got $ex"))
    return ex.args[1]
end

"""
`@fix union([1], [2])` operates on values to produce an instance, whereas
`@FixT union(::Vector{Int64}, ::Vector{Int64})` produces `typeof(@fix union([1], [2]))`
"""
macro FixT(ex)
    try
        Meta.isexpr(ex, :call) || throw(Base.Meta.ParseError("expected a call, got $ex"))
        f = ex.args[1]
        arg_types = map(parse_type_spec, ex.args[2:end])
        arg_types_wrapped = map(ex -> :($(Some){$(ex)}), arg_types)
        f_ex = :(typeof($(f)))
        args = Expr(:curly, :Tuple, arg_types_wrapped...)
        kw = :(NamedTuple{(), Tuple{}}) # TODO perhaps use qualifier, e.g. `Base.Tuple`
        return :(($(Fix)){$(esc(f_ex)), $(esc(args)), $(esc(kw))})
    catch err
        err isa Base.Meta.ParseError || rethrow(err)
        throw(Base.Meta.ParseError("expected e.g. `f(::S, ::T)`, got $ex. Detail: $(err.msg)"))
    end
end

end
