module FixArgs

include("new.jl")
using .New
export Fix1, Fix2

function parse_type_spec(ex)
    Meta.isexpr(ex, :(::), 1) && return (ex.args[1], Some)
    throw(Base.Meta.ParseError("expected a `::T`, got $ex"))
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
        arg_types_wrapped = map(((ex, wrap),) -> :($(wrap){$(esc(ex))}), arg_types)
        f_ex = esc(:(typeof($f)))
        args = Expr(:curly, :Tuple, arg_types_wrapped...)
        call_args = :(New.FrankenTuple{$(args), (), Tuple{}})
        #return :(($(Fix)){$(esc(f_ex)), $(esc(args)), $(esc(kw))})
        return :(New.Call{Some{$(f_ex)}, $(call_args)})
    catch err
        err isa Base.Meta.ParseError || rethrow(err)
        throw(Base.Meta.ParseError("expected e.g. `f(::S, ::T)`, got $ex. Detail: $(err.msg)"))
    end
end

end
