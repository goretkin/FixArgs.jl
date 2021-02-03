"""
Note that `Expr` and `TypedExpr` are constructed slightly differently.
Each argument of an `Expr` is an argument to `Expr`, whereas
all arguments of a `TypedExpr` are passed as one argument (a tuple) to `TypedExpr`

e.g.

`Expr(:call, +, 1, 2)` corresponds to
`TypedExpr(Val{:call}(), (+, 1, 2))`
"""
struct TypedExpr{H, A}
    head::H
    args::A
end

function TypedExpr(expr::Expr)
    TypedExpr(
        typed_expr(expr.head),
        typed_expr(expr.args)
    )
end

typed_expr(args::Vector) = tuple(map(typed_expr, args)...)
typed_expr(sym::Symbol) = Val(sym)
typed_expr(expr::Expr) = TypedExpr(expr)
typed_expr(x) = x

function inv_typed_expr(expr::TypedExpr)
    Expr(
        inv_typed_expr(expr.head),
        inv_typed_expr(expr.args)...
    )
end

inv_typed_expr(args::Tuple) = map(inv_typed_expr, [args...])
inv_typed_expr(val::Val{sym}) where sym = sym
inv_typed_expr(x) = x

function _show_arg_pos(io::IO, i, p)
    print(io, "arg_pos($i, $p)")
end

unwrap_ParentScope(x::ArgPos, p=0) = (x, p)
unwrap_ParentScope(x::ParentScope, p=0) = unwrap_ParentScope(x._, p + 1)

_get(::ArgPos{i}) where {i} = i



lc_expr(expr::TypedExpr{Val{:->}, Tuple{A, B}}) where {A, B} = Lambda(lc_expr(expr.args[1]), lc_expr(expr.args[2]))
lc_expr(expr::TypedExpr{Val{:call}, X}) where {X} = Call(lc_expr(expr.args[1]), map(lc_expr, expr.args[2:end])) # TODO handle TypedExpr with kwargs
lc_expr(expr::TypedExpr{Val{:tuple}, X}) where {X} = map(lc_expr, expr.args)
lc_expr(expr::TypedExpr{Val{:escape}, X}) where {X} = inv_typed_expr(expr)

"""
Lambda-Call expression
"""
lc_expr(x) = x

_get(::Val{x}) where {x} = x

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

macro xquote(ex)
    # TODO escape any e.g. `BoundSymbol` before passing to `designate_bound_arguments`.
    # otherwise cannot distinguish between original `BoundSymbol` and output of `designate_bound_arguments`
    # Then these escaped `BoundSymbol`s should not be touched by `normalize_bound_vars`
    ex1 = clean_expr(ex)
    ex2 = designate_bound_arguments(ex1)

    # escape everything that isn't a bound variable, so that they are evaluated in the macro call context.
    # unquoted `Symbol` comes to represent free variables in the λ calculus (as does e.g. `:(Base.sqrt)`, see `do_escape`)
    # `BoundSymbol{::Symbol}` comes to represent bound variables in the λ calculus
    ex3 = escape_all_but(ex2)
    ex4 = normalize_bound_vars(ex3)
    val = lc_expr(TypedExpr(ex4))
    uneval(val) # note: uneval handles `Expr(:escape, ...)` specially.
end
