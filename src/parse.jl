using MacroTools: @capture, rmlines, unblock

struct BoundSymbol
    _::Symbol
end

struct ArgSymbol
    _::Symbol
end

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

make_label(x) = Symbol("_"^x.antecedent_depth, x.arg_i)

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

function get_label(labeler, labels_stack, sym, referent_depth)
    for (antecedent_depth, labels) = reverse(collect(enumerate(labels_stack)))
        ns = findall(==(sym), labels)
        length(ns) == 0 && continue
        arg_i = only(ns)
        length(ns) == 1 && return labeler((; referent_depth, antecedent_depth, arg_i, sym))
        error("multiple arguments match $sym")
    end
    return sym
end

"""
α-conversion in λ-calculus

`labeler(x)`` produces a `Symbol` or similar from
`x.referent_depth`
`x.antecedent_depth`
`x.arg_i`
`x.sym` -- name before relabeling

`x.referent_depth - x.antecedent_depth` is number of `->`s that are between the evaluation site and the definition site
"""
function relabel_args(is_symbol, labeler, ex, labels_stack = [], this_depth = 1)
    is_symbol(ex) && return get_label(labeler, labels_stack, ex, this_depth)

    next_depth = this_depth
    if ex isa Expr && ex.head == :(->)
        maybe_lambda = parse_lambda(ex)
        labels_stack_ = vcat(labels_stack, [maybe_lambda.args])
        labels_stack = labels_stack_
        next_depth = this_depth + 1
        args_ = relabel_args.(Ref(is_symbol), Ref(labeler), ex.args, Ref(labels_stack), (this_depth, next_depth))
        return Expr(ex.head, args_...)
    end

    if ex isa Expr
        args_ = relabel_args.(Ref(is_symbol), Ref(labeler), ex.args, Ref(labels_stack), Ref(next_depth))
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
