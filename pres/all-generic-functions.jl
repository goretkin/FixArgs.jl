#=
using StatsBase: countmap
function all_generic_functions_n_methods()
    return subtypes(Function) |>
    fs -> filter(Base.issingletontype, fs) |>
    fs -> map(tf -> tf.instance, fs) |>
    fs -> map(f -> (length(methods(f)), f), fs) |>
    nfs -> sort(nfs, by=first)
end

generic_functions_n_methods = all_generic_functions_n_methods()
freq_n_methods = StatsBase.countmap(map(first, generic_functions_n_methods))
sort(pairs(freq_n_methods)) # see how many functions have how many methods
nfs = filter(nf -> nf[1] > 20, generic_functions_n_methods)
arities(f) = Set(map(m -> m.nargs - 1, methods(f).ms))
arity(method) = fieldtype

methods_df(f) = DataFrame(method=methods(join).ms)
=#

function has_vararg(@nospecialize sig)
    try
        fieldcount(sig)
        return false
    catch e
        e isa ArgumentError && return true
        rethrow(e)
    end
end

using ProgressMeter: @showprogress
using DataFrames

function all_functions_df(;min_n_methods)
    df = DataFrame(
        func = Vector{Function}(),
        is_defined = Vector{Bool}(),
        n_methods = Vector{Int}()
    )

    @showprogress for T in subtypes(Function)
        Base.issingletontype(T) || continue
        f = T.instance
        n_methods = length(methods(f))
        n_methods >= min_n_methods || continue
        push!(df,
            (
                func = f,
                is_defined = isdefined(Main, Symbol(string(f))),
                n_methods = n_methods
            )
        )
    end
    return df
end

function all_methods_df(functions_df)
    df = DataFrame(
        func = Vector{Function}(),
        method = Vector{Method}(),
        vararg = Vector{Bool}(),
        arity = Vector{Int64}(),
        sig = Vector{Any}(),
    )

    @showprogress for f in functions_df.func
        ms = methods(f)
        for m in ms
            push!(df,
                (
                    func = f,
                    method = m,
                    vararg = has_vararg(m.sig),
                    arity = m.nargs - 1,
                    sig = m.sig,
                )
            )
        end
    end

    return df
end

using TableView
using Blink

functions_df = all_functions_df(min_n_methods=15)
w = Blink.Window()
body!(w, showtable(functions_df))

mega_methods_table = all_methods_df(functions_df)
gdf = groupby(mega_methods_table, [:func, :vararg, :arity])
cdf = combine(gdf) do df
    (
        n_methods = nrow(df),
        joined_sig = reduce(typejoin, df.sig)
    )
end

w = Blink.Window()
body!(w, showtable(cdf))
