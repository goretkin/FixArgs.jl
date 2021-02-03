function Base.show(io::IO, a::Union{ParentScope, ArgPos{i} where i})
    (_a, p) = unwrap_ParentScope(a)
    _show_arg_pos(io, _get(_a), p)
end

Base.show(io::IO, x::Lambda) = Show._show_without_type_parameters(io, x)
Base.show(io::IO, x::Call) = Show._show_without_type_parameters(io, x)

# show consistent with constructor that is consistent with type alias
function Base.show(io::IO, x::FixNew)
    print(io, "FixNew")
    print(io, "(")
    show(io, x.args)
    print(io, ",")
    show(io, x.body.f)
    print(io, ",")
    show(io, x.body.args)
    print(io, ")")
end

# show consistent with constructor that is consistent with type alias

function Base.show(io::IO, x::Fix1)
    print(io, "Fix1")
    print(io, "(")
    show(io, x.body.f)
    print(io, ",")
    show(io, x.body.args[1])
    print(io, ")")
end

function Base.show(io::IO, x::Fix2)
    print(io, "Fix2")
    print(io, "(")
    show(io, x.body.f)
    print(io, ",")
    show(io, x.body.args[2])
    print(io, ")")
end