# FixArgs

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://goretkin.github.io/FixArgs.jl/dev)
[![Build Status](https://github.com/goretkin/FixArgs.jl/workflows/CI/badge.svg)](https://github.com/goretkin/FixArgs.jl/actions)
[![Coverage](https://codecov.io/gh/goretkin/FixArgs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/goretkin/FixArgs.jl)

This package aims to generalize `Base.Fix1` and `Base.Fix2` for arbitrary function arities and binding patterns with a type `Fix`.
`Fix` can also include keyword arguments.
One day, parts of this package may be included in Julia's `Base` itself; see [issue #36181](https://github.com/JuliaLang/julia/issues/36181).

A key aspect of `Fix` and the special cases in `Base` is that methods can dispatch on the fixed function and the signature (which argument positions are bound, and their types).
Dispatch is not tenable with anonymous functions:

```julia
julia> f1 = x -> x == 0
#1 (generic function with 1 method)

julia> f2 = Base.Fix1(==, 0)
(::Base.Fix1{typeof(==),Int64}) (generic function with 1 method)

julia> f3 = x -> x == 0
#3 (generic function with 1 method)

julia> f4 = Base.Fix1(==, 0)
(::Base.Fix1{typeof(==),Int64}) (generic function with 1 method)

julia> typeof(f2) === typeof(f4)
true

julia> typeof(f1), typeof(f3)
(var"#1#2", var"#3#4")
```

An anonymous function is always given a unique type, which allows methods to specialize on the specific anonymous function passed as an argument, but does not permit dispatch.

Dispatching on the `Fix` type enables a certain form of symbolic computation.
For example, take [a specific method of the `findfirst` function](https://github.com/JuliaLang/julia/blob/1f9e8bdbcf0ded6f1386f9329a284366dbb56120/base/array.jl#L1878-L1879):

```julia
findfirst(p::Union{Fix2{typeof(isequal),Int},Fix2{typeof(==),Int}}, r::OneTo{Int}) =
    1 <= p.x <= r.stop ? p.x : nothing
```

The fallback for `findfirst` (triggered by e.g. `findfirst(x->x==3, 1:10)` instead of `findfirst(==(3), 1:10)`) would produce the same (correct) answer, but the method above will be quicker.

This perspective of enabling "symbolic computation" is underscored by the fact that the `Fix` type may bind _every_ argument of a function.
It can therefore serve the purpose of representing a delayed function evaluation (see the Wikipedia article on [Lazy Evaluation](https://en.wikipedia.org/wiki/Lazy_evaluation)).
Again, the approach of this package allows an additional benefit to the technique of creating a _thunk_(an anonymous function that takes no arguments), since methods can dispatch on details about the lazy evaluation.

In many domains, new types are introduced to represent essentially these thunks. See the tests for some examples.
In essence, this package can allow you to use systematic names for these types by leveraging existing function types.
One example to demonstrate this point is to replace the `Rational` type in favor of a type written in terms of `Fix` and a function representing division, e.g. `/`.
This also showcases some convenience macros for constructing these types.

```julia
julia> 1/9 * 3/2 # eager division
0.16666666666666666

julia> using FixArgs

julia> (@fix 1/9) * (@fix 3/2) # lazy division
ERROR: MethodError: no method matching *(::Fix{typeof(/),Tuple{Some{Int64},Some{Int64}},NamedTuple{(),Tuple{}}}, ::Fix{typeof(/),Tuple{Some{Int64},Some{Int64}},NamedTuple{(),Tuple{}}})
Closest candidates are:
  *(::Any, ::Any, ::Any, ::Any...) at operators.jl:538
Stacktrace:
 [1] top-level scope at REPL[33]:1

julia> function Base.:*( # ... Define the missing method. See test

julia> (@fix 1/9) * (@fix 3/2)
(::Fix{typeof(/),Tuple{Some{Int64},Some{Int64}},NamedTuple{(),Tuple{}}}) (generic function with 1 method)

julia> ans.args
(Some(1), Some(6))

julia> 1//9 * 3//2 # use Rational
1//6
```



Related features in other languages:
- [C++'s std::bind](https://en.cppreference.com/w/cpp/utility/functional/bind)
- [Python's functools.partial](https://docs.python.org/3/library/functools.html#functools.partial)
