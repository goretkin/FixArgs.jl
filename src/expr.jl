# copied from MacroTools:
walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))

"""
    postwalk(f, expr)

Applies `f` to each node in the given expression tree, returning the result.
`f` sees expressions *after* they have been transformed by the walk.

See also: [`prewalk`](@ref).
"""
function postwalk(f, x)
    walk(x, x -> postwalk(f, x), f)
end

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


# copied from:
# https://github.com/schlichtanders/ExprParsers.jl/blob/10d32171128b92ddf4758de8dbcbfe51cf2bb4eb/src/Utils.jl#L15-L39
"""
    isexpr(expr) -> Bool
    isexpr(expr, head) -> Bool
Checks whether given value isa `Base.Expr` and if further given `head`, it also checks whether
the `head` matches `expr.head`.
# Examples
```julia
julia> using ExprParsers
julia> EP.isexpr(:(a = hi))
true
julia> EP.isexpr(12)
false
julia> EP.isexpr(:(f(a) = a), :(=))
true
julia> EP.isexpr(:(f(a) = a), :function)
false
```
"""
isexpr(::Expr) = true
isexpr(other) = false
isexpr(expr::Expr, head::Symbol) = expr.head == head
isexpr(other, head::Symbol) = false

# copied from:
# https://github.com/schlichtanders/ExprParsers.jl/blob/10d32171128b92ddf4758de8dbcbfe51cf2bb4eb/src/expr_parsers_with_parsed.jl#L469-L490
function _extract_args_kwargs__collect_all_kw_into_kwargs(expr_args)
    args = []
    kwargs = []

    otherargs, parameters = if isempty(expr_args)
      [], []
    elseif isexpr(expr_args[1], :parameters)
      expr_args[2:end], expr_args[1].args
    else
      expr_args, []
    end

    for p in otherargs
      if isexpr(p, :kw)
        push!(kwargs, p)
      else
        push!(args, p)
      end
    end
    append!(kwargs, parameters)
    args, kwargs
end

function _kwargs_to_named_tuple(kwargs)
    all(ex -> isexpr(ex, :kw), kwargs) || error()
    all(ex -> length(ex.args) == 2, kwargs) || error()
    (; (ex.args[1] => ex.args[2] for ex in kwargs)... )
end
