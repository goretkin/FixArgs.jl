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

lc_expr(expr::TypedExpr{Val{:->}, Tuple{A, B}}) where {A, B} = Lambda(lc_expr(expr.args[1]), lc_expr(expr.args[2]))
lc_expr(expr::TypedExpr{Val{:call}, X}) where {X} = Call(lc_expr(expr.args[1]), map(lc_expr, expr.args[2:end])) # TODO handle TypedExpr with kwargs
lc_expr(expr::TypedExpr{Val{:tuple}, X}) where {X} = map(lc_expr, expr.args)
lc_expr(expr::TypedExpr{Val{:escape}, X}) where {X} = inv_typed_expr(expr)

"""
Lambda-Call expression
"""
lc_expr(x) = x

