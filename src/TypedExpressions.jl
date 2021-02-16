"""
Roughly mirror `Base.Expr`, except that the the head of the expression (encoded in the `head` field)
can be dispatched on.

This is only used in an intermediate representation of this package.

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

lc_expr(expr::TypedExpr{Val{:->}, Tuple{A, B}}) where {A, B} = Lambda(lc_expr(expr.args[1]), lc_expr(expr.args[2]))

function lc_expr(expr::TypedExpr{Val{:call}, X}) where {X}
    _expr = inv_typed_expr(expr)
    (_args, _kwargs) = _extract_args_kwargs__collect_all_kw_into_kwargs(_expr.args[2:end])
    f = lc_expr(expr.args[1])
    args = map(lc_expr ∘ typed_expr, tuple(_args...))  # TODO ensure it's a `::Tuple`
    kwargs =  _kwargs_to_named_tuple(_kwargs)
    Call(f, FrankenTuple(args, kwargs))
end

lc_expr(expr::TypedExpr{Val{:tuple}, X}) where {X} = map(lc_expr, expr.args)
lc_expr(expr::TypedExpr{Val{:escape}, X}) where {X} = inv_typed_expr(expr)

"""
Convert a `::TypedExpr` to a Lambda-Call expression
"""
lc_expr(x) = x
