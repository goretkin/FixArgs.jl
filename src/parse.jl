using MacroTools: rmlines, unblock

function parse_lambda(ex)
    arrow = :(->)
    matched = @capture ex (args__,) -> body_
    body = unblock(body)
    matched && return (;args, body)

    matched = @capture ex arg_ -> body_
    args = Vector{Any}([arg])
    body = unblock(body)
    matched && return (;args, body)
    return nothing
end

function parse_call(ex)
    matched = @capture ex f_(args__)
    matched && return (;f, args)
    return nothing
end

function get_label(labels_stack, sym::Symbol)
    for (depth, labels) = reverse(collect(enumerate(labels_stack)))
        ns = findall(==(sym), labels)
        length(ns) == 0 && continue
        length(ns) == 1 && return Symbol("_"^depth, only(ns))
        error("multiple arguments match $sym")
    end
    return sym
end

function number_label_args(ex, labels_stack = [])
    ex isa Symbol && return get_label(labels_stack, ex)
    @show ex 
    @show labels_stack
    println()
    if ex isa Expr && ex.head == :(->)
        maybe_lambda = parse_lambda(ex)
        labels_stack_ = vcat(labels_stack, [maybe_lambda.args])
        labels_stack = labels_stack_
    end

    if ex isa Expr
        args_ = number_label_args.(ex.args, Ref(labels_stack))
        return Expr(ex.head, args_...)
    end

    return ex   # LineNumberNode, etc.
end

ex1 = :(
    (x, y, z) -> f(g(x, y), h(x, z))
)

ex2 = :(
    x -> (y -> *(x, y))
)

ex3 = :(
    (x, y) -> map(z -> *(x, z), y)
)