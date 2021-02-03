"""
Represent the arity of a function (i.e. how many inputs it takes)

`P` is 0, 1, 2, ...
`KW` is always `NoKeywordArguments`, and may be extended in the future.
"""
# both `P` and `KW` may be extended in the future to allow default arguments
# (this could become a very generalized notion of function arity)
struct Arity{P, KW}
end

# TODO choose a representation for keyword arguments
const NoKeywordArguments = Nothing

function Arity(p_arity, kw_arity = NoKeywordArguments)
    return Arity{p_arity, NoKeywordArguments}()
end
"""
Represent the formal parameters of "this" function.
"""
struct ArgPos{N}
end

ArgPos(i) = ArgPos{i}()

"""
Nest `ArgPos` in `ParentScope`s to represent a reference to the formal parameters of a "parent" function.
Forms a unary representation.

Related: https://en.wikipedia.org/wiki/De_Bruijn_index
"""
struct ParentScope{T}
    _::T
end

function arg_pos(i, p)
    p >= 1 || error()
    p == 1 && return ArgPos(i)
    ParentScope(arg_pos(i, p - 1))
end

struct Lambda{A, B}
    args::A
    body::B
end

struct Call{F, A}
    f::F
    args::A
end
