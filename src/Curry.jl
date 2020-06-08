module Curry

using Base: tail
export Bind, @bind

"""
Return a `Tuple` that interleaves `args` into the `nothing` slots of `slots`.
"""
function interleave(slots, args) end

interleave(bind::Tuple{}, args::Tuple{}) = ()
interleave(bind::Tuple{}, args::Tuple) = error("more args than positions")
interleave(bind, args) = _interleave(first(bind), tail(bind), args)

# `nothing` indicates a position to be bound
_interleave(firstbind::Nothing, tailbind::Tuple, args::Tuple) = (
  first(args), interleave(tailbind, tail(args))...)

# allow escaping of e.g. `nothing`
_interleave(firstbind::Some{T}, tailbind::Tuple, args::Tuple) where T = (
  something(firstbind), interleave(tailbind, args)...)

_interleave(firstbind::T, tailbind::Tuple, args::Tuple) where T = (
  firstbind, interleave(tailbind, args)...)

struct Bind{F, A} <: Function
    f::F
    a::A
end

function (c::Bind)(args...)
    c.f(interleave(c.a, args)...)
end

"""
`@bind f(a,b)` is equivalent to `Bind(f, (a, b))`
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
