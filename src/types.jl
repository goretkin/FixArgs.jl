"""

Represent the [arity](https://en.wikipedia.org/wiki/Arity) of a [`Lambda`](@ref).

Currently, only represents a fixed number of positional arguments, but may be generalized to include optional and keyword arguments.

`P` is 0, 1, 2, ...
`KW` is always `NoKeywordArguments`, and may be extended in the future.
"""
struct Arity{P, KW}
end

# TODO choose a representation for keyword arguments
const NoKeywordArguments = Nothing

function Arity(p_arity, kw_arity = NoKeywordArguments)
    return Arity{p_arity, NoKeywordArguments}()
end

"""
Within the `body` of a [`Lambda`](@ref), represent a formal positional parameter of that[`Lambda`](@ref).
"""
struct ArgPos{N}
end

ArgPos(i) = ArgPos{i}()

"""
Nest [`ArgPos`](@ref) in [`ParentScope`](@ref)s to represent a reference to the formal parameters of a "parent" function.
Forms a unary representation.

Related: [De Bruijn indices]https://en.wikipedia.org/wiki/De_Bruijn_index
"""
struct ParentScope{T}
    _::T
end

function arg_pos(i, p)
    p >= 1 || error()
    p == 1 && return ArgPos(i)
    ParentScope(arg_pos(i, p - 1))
end

"""
A lambda expression "args -> body"
"""
struct Lambda{A, B}
    args::A
    body::B
end

"""
A call "f(args...)". `args` may represent both positional and keyword arguments.
"""
struct Call{F, A}
    f::F
    args::A
end
