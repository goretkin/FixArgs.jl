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

cleanexpr(ex) = MacroTools.flatten(MacroTools.striplines(ex))

function build_fix(ex, labels = nothing)
    println()
    @show MacroTools.prettify(ex)
    # @show ex
    @show labels

    if ex isa Expr && ex.head === :(->)
        println("λ")
        lambda = parse_lambda(ex)
        labels_ = lambda.args
        inner_fix = build_fix(lambda.body, labels_)
        labels === nothing && return inner_fix
        @show inner_fix
        return build_fix(inner_fix, labels)
    end

    if ex isa Expr && ex.head === :call
        q_f = ex.args[1]
        println("call: $q_f")
        if eval(q_f) !== Template
            q_a = Tuple(ex.args[2:end])
            q_a_ = build_fix.(q_a, Ref(labels))
            @show q_a_
            return cleanexpr(quote
                Fix(
                    $(esc(q_f)),
                    Template(($(q_a_...),))
                )
            end)
        end
    end

    if true # want it to work for all literals
        println("not lambda, not call")
        labels === nothing && return ex
        i = findonly(==(ex), labels)
        println("i is $i")
        i === nothing && return cleanexpr(quote
            ($(esc(ex))) # wrap with Some afterwards
        end)
        return cleanexpr(quote
            ArgPos{$(i)}()
        end)
    end
    println("fallthrough")
    return ex   # LineNumberNode, etc.
end

macro fixxx(ex)
    build_fix(ex)
end

test_lambdas = [
    (
        :(() -> /(1, 2)),
        :(
            Fix(/, Template((Some(1), Some(2))))
        )
    ),
    (
        :(y -> *(x, y)),
        :(
            Fix(*, Template((Some(x), ArgPos{1}())))
        )
    ),
    (
        :(x -> x),
        missing # throw an error
    ),
    (
        :(x -> identity(x)),
        missing
    ),
    (
        :((x) -> f(() -> x)),
        missing # throw an error
    ),
    (
        :((f, x) -> f(() -> x)),
        missing # throw an error
    ),
    (
        :((x) -> f(() -> identity(x))),
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
        :(
            Fix(
                Fix,
                Template((
                    Some(*),
                    Template((
                        ArgPos{1}(),
                        Some(ArgPos{1}())
                    ))
                ))
            )
        )
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


build_fix(:(
    () -> identity(x)
))
@fixxx () -> identity(x)

#=
(...) -> f(...) <=> Fix(f, ...)

=#

bar = (x, z) -> map(y -> *(x, y), z)

# y -> *(x, y)
# Fix(*, Template((Some(x), ArgPos(1))))

# x -> (y -> *(x, y))
# x -> Fix(*, Template((Some(x), ArgPos(1))))
#=
Fix(
    Fix,
    Template((
        Some(*),
        Template((  # not escaped with Some
            ArgPos{1}(),
            Some(ArgPos{1}())
        ))
    ))
)
=#
