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

Fix(f, args) = Fix(f, args, NamedTuple())

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
interleave(bind::Tuple, args) = _interleave(first(bind), tail(bind), args)
interleave(bind::Tuple{}, args::Tuple{}) = ()
interleave(bind::Tuple{}, args::Tuple) = error("more args than positions")

# `nothing` indicates a position to be bound
_interleave(firstbind::Nothing, tailbind::Tuple, args::Tuple) = (
    first(args), interleave(tailbind, tail(args))...)

# allow escaping of e.g. `nothing` and `Val(7)()``
_interleave(firstbind::Some{T}, tailbind::Tuple, args::Tuple) where T = (
    something(firstbind), interleave(tailbind, args)...)

# first position is bound
_interleave(firstbind::T, tailbind::Tuple, args::Tuple) where T = (
    firstbind, interleave(tailbind, args)...)

# recursively evaluate unescaped `Fix`
_interleave(firstbind::Fix, tailbind::Tuple, args::Tuple) where T = (
    firstbind((first(args)::Tuple)...), interleave(tailbind, tail(args))...)

# first position is bound with `::Val`
_interleave(firstbind::Val{arg_bind}, tailbind::Tuple, args::Tuple) where arg_bind = (
    arg_bind, interleave(tailbind, args)...)

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
function fix(f, args...; kw...)
    # TODO allow robust selection of `Template`, even if there are no `ArgPos`s
    # Or remove sequence-based approach altogether
    if any(x -> x isa ArgPos, args)
        Fix(f, Template(args), kw.data)
    else
        Fix(f, args, kw.data)
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


# `Fix.args::Tuple` is the (previous) sequential, descending behavior
# `Fix.args::Template{Tuple}` is the (new) position, "flat" behavior
struct Template{T}
    _::T
end

struct ArgPos{N} # lens into argument position
end

_interweave(::ArgPos{N}, args::Tuple) where N = args[N]
_interweave(::Val{ARG_BIND}, args::Tuple) where ARG_BIND  = ARG_BIND
_interweave(arg_bind::Some{<:Any}, args::Tuple) = something(arg_bind)

# recursively evaluate unescaped `Fix`
_interweave(fix::Fix, args::Tuple) = fix(args...)

# TODO handle `Val` too?
_wrap_nested_sub(a::ArgPos) = a
_wrap_nested_sub(a) = Some(a)
# recursively substitute nested structural lambda
_interweave(t::Template, args::Tuple) = Template(map(_wrap_nested_sub, interweave(t._, args)))

function interweave(template::Tuple, args::Tuple)
    # `map` seems to infer better than `ntuple`
    # ntuple(i -> _interweave(template[i], args), length(template))
    map(t -> _interweave(t, args), template)
end

interleave(bind::Template, args) = interweave(bind._, args)

# if macro invocation contains a "bare" argument, wrap it
SomeUnlessNot(x) = Some(x)

# exceptions
SomeUnlessNot(x::Fix) = x
SomeUnlessNot(x::Val) = x

# `Some` is used to escape the exceptions, do not wrap again
SomeUnlessNot(x::Some{<:Fix}) = x
SomeUnlessNot(x::Some{<:Val}) = x

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
        Expr(:call, SomeUnlessNot, ex)
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
