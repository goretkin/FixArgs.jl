using MacroTools: @capture, rmlines, unblock

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

make_label(depth, arg_i) = Symbol("_"^depth, arg_i)

function parse_label(s)
    depth = 0
    while depth + 1 <= length(s) && s[depth + 1] == '_'
        depth += 1
    end
    depth == 0 && return nothing
    depth+1 > length(s) && error("all underscore identifier?")
    arg_i = parse(Int, s[(depth+1):end])
    return (;depth, arg_i)
end
parse_label(s::Symbol) = parse_label(string(s))

function get_label(labels_stack, sym::Symbol)
    for (depth, labels) = reverse(collect(enumerate(labels_stack)))
        ns = findall(==(sym), labels)
        length(ns) == 0 && continue
        length(ns) == 1 && return make_label(depth, only(ns))
        error("multiple arguments match $sym")
    end
    startswith(string(sym), "_") && error("Cannot capture $sym because it conflicts with number label")
    return sym
end

function number_label_args(ex, labels_stack = [])
    ex isa Symbol && return get_label(labels_stack, ex)

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

function findonly(f, v)
    rs = findall(f, v)
    length(rs) == 0 && return nothing
    length(rs) == 1 && return only(rs)
    error("multiple matches: $(rs)")
end

using FixArgs: Template, ArgPos

test_lambdas = [
    (
        :(() -> /(1, 2)),
        missing
    ),
    (
        :(y -> *(x, y)),
        missing
    ),
    (
        :(x -> x),
        missing
    ),
    (
        :(x -> f(() -> x)),
        missing
    ),
    (
        :((f, x) -> f(() -> x)),
        missing
    ),
    (
        :(x -> f(x)),
        missing # technically contains more information than just `f`, because it limits it to being a 1-arg
    ),
    (
        :((x...) -> f(x...)),
        missing # throw an error
    ),
    (
        :(() -> g(x)),
        missing
    ),
    (
        :(x -> f(() -> g(x))),
        missing
    ),
    (
        :((f, x) -> f(x)),
        missing
    ),
    (
        :((f, x) -> f(() -> identity(x))),
        missing
    ),
    (
        :((f, x) -> f(identity(x))),
        missing
    ),
    (
        :(x -> (y -> *(x, y))),
        missing
    ),
    (
        :((x, z) -> map(y -> *(x, y), z)),
        missing
    ),
    (
        :((x, y) -> f(x, g(y))),
        missing
    ),
    (
        :((x, y) -> f(x, () -> g(y))),
        missing
    ),
    (
        :((x, y, z) -> f(g(x, y), h(x, z))),
        missing
    ),
]
