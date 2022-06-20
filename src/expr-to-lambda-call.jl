
"""
Convert an expression (e.g. an `Expr`) to a Lambda-Call value
"""
lc_expr(x) = x
function lc_expr(expr::Expr)
    if expr.head === :->
        length(expr.args) == 2 || error()
        return Lambda(lc_expr(expr.args[1]), lc_expr(expr.args[2]))
    end

    if expr.head === :call
        _expr = expr
        (_args, _kwargs) = _extract_args_kwargs__collect_all_kw_into_kwargs(_expr.args[2:end])
        f = lc_expr(expr.args[1])
        args = map(lc_expr, tuple(_args...))  # TODO ensure it's a `::Tuple`
        kwargs =  _kwargs_to_named_tuple(_kwargs)
        return Call(f, FrankenTuple(args, kwargs))
    end

    if expr.head === :tuple
        return map(lc_expr, expr.args)
    end

    if expr.head === :escape
        _expr = expr
        return expr
    end

    return error()
end
