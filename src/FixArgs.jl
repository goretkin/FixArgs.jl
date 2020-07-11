module FixArgs

using Base: tail
export Fix, @fix, fix

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

"""
Represent a function call, with partially bound arguments.
"""
struct Fix{F, A, K} <: Function
    f::F
    a::A
    k::K
end

Fix(::Type{T}, a, k) where {T} = Fix{Type{T}, typeof(a), typeof(k)}(T, a, k)

function (c::Fix)(args...; kw...)
    c.f(interleave(c.a, args)...; c.k..., kw...)
end

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
fix(f, args...; kw...) = Fix(f, args, kw)

"""
`@fix f(a,b)` macroexpands to `fix(f, a, b)`

"""
macro fix(ex)
    ex.head == :call || error()
    # `ex.args[1]` is the function and `ex.args[2:end]` are the positional arguments
    return :($fix($(map(esc, ex.args)...)))
end

end
