# copied from MacroTools:
walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))

"""
    postwalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *after* they have been transformed by the walk.

See also: [`prewalk`](@ref).
"""
postwalk(f, x) = walk(x, x -> postwalk(f, x), f)

"""
    prewalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *before* they have been transformed by the walk, and the
walk will be applied to whatever `f` returns.

This makes `prewalk` somewhat prone to infinite loops; you probably want to try
[`postwalk`](@ref) first.
"""
function prewalk(f, x, state)
    (x′, state′) = f(x, state)
    walk(x′, x -> prewalk(f, x, state′), identity)
end

function do_escape(s::Symbol)
    return true
end

function do_escape(s::QuoteNode)
    @show s
    return true
end

function do_escape(e::Expr)
    e.head === :call && return false
    e.head === :-> && return false
    e.head === :tuple && return false # preserve argument (args[1]) of a `->`
    return true # to escape e.g. `Base.sqrt`
end

function do_escape(e::BoundSymbol)
    return false
end

do_escape(e) = false # all else

function _apply_once(check, apply)
    function walk_f(x, s)
        if s === :init && check(x)
            (apply(x), :applied)
        else
            (x, s)
        end
    end
    return walk_f
end

apply_once(check, apply, ex) = prewalk(_apply_once(check, apply), ex, :init)

designate_bound_arguments(ex) = relabel_args(x -> x isa Symbol, x -> BoundSymbol(x.sym), ex)

function normalize_bound_vars(ex)
    placeholder_symbol = :_

    # relabel all `BoundSymbol`s:
    # key: head -> body
    # those in bodies get renamed by `arg_pos`
    # those in heads get renamed to a placeholder
    function relabeler(x)
        (i, p) = (x.arg_i, x.referent_depth - x.antecedent_depth)
        p == 0 && return BoundSymbol(placeholder_symbol)
        return arg_pos(i, p)
    end

    ex1 = relabel_args(
        x -> x isa BoundSymbol,
        relabeler,
    ex)

    # replace all heads, which should all be placeholders with `Arity`
    # TODO ensure all heads were replaced (any heads without all placeholders is an error at this point)
    function check(ex)
        ex isa Expr && ex.head === :tuple && all(==(BoundSymbol(placeholder_symbol)), ex.args)
    end

    function apply(ex)
        n = length(ex.args)
        return Arity(n)
    end

    return apply_once(check, apply, ex1)
end
