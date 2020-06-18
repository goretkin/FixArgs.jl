module Curry

using Base: tail
export Bind, @bind

"""
Return a `Tuple` that interleaves `args` into the `nothing` slots of `slots`.

```jldoctest
using Curry
Curry.interleave((:a, nothing, :c, nothing), (12, 34))

# output

(:a, 12, :c, 34)
```

Use `Some` to escape `nothing`

```jldoctest
using Curry
Curry.interleave((:a, Some(nothing), :c, nothing), (34,))

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
struct Bind{F, A, K} <: Function
    f::F
    a::A
    k::K
end

function (c::Bind)(args...; kw...)
    c.f(interleave(c.a, args)...; c.k..., kw...)
end

"""
    `bind(f, a, b)`
    `bind(f, args...; kw...)`

The `bind` function partially evaluates `f` by binding some of its arguments.
Positional arguments of `f` that should not be bound are indicated by passing `nothing`
to `bind` at the respective position.
```jldoctest
julia> using Curry: bind

julia> b = bind(+, 1, 2); # no nothing, all arguments bound

julia> b()
3

julia> b = bind(*, "hello", nothing); # only first argument bound

julia> b(", world")
"hello, world"

julia> b = bind(=>, nothing, 1); # second argument bound

julia> b("one")
"one" => 1

julia> b = bind(isapprox, nothing, nothing, atol=100); # only atol keyword bound

julia> b(10, 20)
true

julia> b(10, 20, atol=1) # keywords can be reassigned on the fly
false
```
"""
bind(f, args...; kw...) = Bind(f, args, kw)

"""
`@bind f(a,b)` macroexpands to `bind(f, a, b)`

"""
macro bind(ex)
    ex.head == :call || error()
    # `ex.args[1]` is the function and `ex.args[2:end]` are the positional arguments
    return :($bind($(map(esc, ex.args)...)))
end

end
