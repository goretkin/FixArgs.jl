struct Arity{P, KW}
end

# TODO choose a representation for keyword arguments
const NoKeywordArguments = Nothing
function Arity(p_arity, kw_arity = NoKeywordArguments)
    return Arity{p_arity, NoKeywordArguments}()
end
struct ArgPos{N}
end

ArgPos(i) = ArgPos{i}()

function arg_pos(i, p)
    p >= 1 || error()
    p == 1 && return ArgPos(i)
    ParentScope(arg_pos(i, p - 1))
end
struct ParentScope{T}
    _::T
end

struct Lambda{A, B}
    args::A
    body::B
end

struct Call{F, A}
    f::F
    args::A
end
