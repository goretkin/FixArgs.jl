module Curry

using Base: tail
export Bind, @bind

"""
Return a `Tuple` that interleaves `args` into the `nothing` slots of `slots`.

```jldoctest
Curry.interleave((:a, nothing, :c, nothing), (12, 34))

# output

(:a, 12, :c, 34)
```

Use `Some` to escape `nothing`

```jldoctest
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

```jldoctest
b = Bind(+, (1, 2))
b()

# output

3
```

```jldoctest
b = Bind(*, ("hello", nothing))
b(", world")

# output

"hello, world"
```

`Bind(f, (g(), h()))` is like `:(f(g(), h()))` but `f` `g` and `h` are lexically scoped, and `g()` and `h()` are evaluated eagerly.
"""
struct Bind{F, A} <: Function
    f::F
    a::A
end

function (c::Bind)(args...)
    c.f(interleave(c.a, args)...)
end

"""
`@bind f(a,b)` is equivalent to `Bind(f, (a, b))`

TODO generalize to not 2 arguments
"""
macro bind(ex)
    ex.head == :call || error()
    f = ex.args[1]
    x = tuple(ex.args[2:end]...)
    quote
        Bind($(f), ($(esc(x[1])), $(esc(x[2])))) # TODO how to use splatting to generalize to n arguments
    end
end


end
