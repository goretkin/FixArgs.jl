# FixArgs.jl

```@contents
Depth = 3
```
# Introduction
This package began as an exploration in generalizing `Base.Fix1` and `Base.Fix2`.
These types are ways to represent a particular forms of anonymous functions.
Let's illustrate. We'll use the `string` function in `Base`, which concatenates the string representations of its arguments:

```@repl
string("first ", "second")
```

Now, to construct and use the `Fix1` and `Fix2` types:
```@repl BaseFix
using Base: Fix1, Fix2

f1 = Fix1(string, "one then ")
f1("two")
```
The function-call behavior of `Fix1(f, bind)` is the same as `x -> f(bind, x)`.

Similarly,

```@repl BaseFix
f2 = Fix2(string, " before two")
f2("one")
```
The function-call behavior of `Fix2(f, bind)` is the same as `x -> f(x, bind)`.

The key point of the `Fix1` and `Fix2` types is that methods can dispatch on
1. the type of `f`
2. the type of `bind`
3. the position of `bind` within the function call

Dispatch is not tenable with anonymous functions. Let's illustrate while moving to a more practical example using `==` instead of `string`.

```@repl BaseFix
f1 = x -> x == 0
f2 = Fix1(==, 0)
```

Now define the "same" things again:
```@repl BaseFix
f3 = x -> x == 0
f4 = Fix1(==, 0)
```

The types of both the `Fix1` values is the same:
```@repl BaseFix
typeof(f2) === typeof(f4)
```

But each anonymous function definition introduces a new type with an opaque name:
```@repl BaseFix
typeof(f1), typeof(f3)
```

A new anonymous function is always given a unique type, which allows methods to specialize on the specific anonymous function passed as an argument, but does not "permit" dispatch. To be more accurate, as far as dispatch is concerned, the type of anonymous functions is not special:

```@repl BaseFix
foo(::typeof(f1)) = "f1"
foo(::typeof(f3)) = "f3"
foo(f1)
foo(f3)
```

But really we'd like to use a type that is less opaque and furthermore is "structural" in some ways, rather than purely "nominal".

## Examples of `Base.Fix2`
Where is it useful to dispatch on these special functions?
Because `Base` [does not export](https://github.com/JuliaLang/julia/issues/36554) and
[does not document](https://github.com/JuliaLang/julia/pull/36094) these types,
there aren't methods [in the Julia ecosystem](https://juliahub.com/ui/RepoSearch?q=%3A%3A%28Base%5C.%29%3FFix%5B12%5D&r=true).

But these types are constructed with, for example, `==(3)` or `in([1, 2, 3])`.
A type like these is useful as a predicate to pass to higher-order functions, e.g. `findfirst(==(3), some_array)` to find the first element that equals `3`.
Brevity asside, these types are useful to define more efficient methods of generic higher-order functions.
For example, take [a specific method of the `findfirst` function](https://github.com/JuliaLang/julia/blob/1f9e8bdbcf0ded6f1386f9329a284366dbb56120/base/array.jl#L1878-L1879):

```julia
findfirst(p::Union{Fix2{typeof(isequal),Int},Fix2{typeof(==),Int}}, r::OneTo{Int}) =
    1 <= p.x <= r.stop ? p.x : nothing
```

The fallback for `findfirst` (triggered by e.g. `findfirst(x->x==3, 1:10)` instead of `findfirst(==(3), 1:10)`) would produce the same (correct) answer, but the method above will be quicker.


Dispatching on the *structure* of the predicate function enables a certain form of symbolic computation.

# Symbolic computation and lazy evaluation
This package provides a generalization of `Fix1` and `Fix2` in a few ways:
1. A function of any positional arity can be used, and any number of its arguments can be bound, allowing the remaining arguments to be provided later.
2. A function can have its keyword arguments bound.
3. The function `x -> f(x, b)` is represented with types:
   - a [`Lambda`](@ref) to represent function (`args -> body`),
   - a [`Call`](@ref) to represent the function *call* (`f(...)` in the body.
   - a [`ArgPos`](@ref) to represent the `x` in the body of the lambda function.

The third generalization is powerful, because it's effectively the [lambda calculus](https://en.wikipedia.org/wiki/Lambda_calculus).

It is worth considering first just [`Call`](@ref), which can serve the purpose of representing a [delayed function call evaluation](https://en.wikipedia.org/wiki/Lazy_evaluation).
If you prefer, you may also consider a [thunk](https://en.wikipedia.org/wiki/Thunk) `() -> foo(1, 2)`, which would be a `Lambda` (with no arguments) *and* a `Call` that does not mention any "free variables".

If laziness is all that is needed, then defining a Julia anonymous function will do the job.
But this package allows an additional benefit since methods can dispatch on details of the lazy call.

In many domains, new types are introduced to represent this pattern.
## `Base.Iterators`
`Base.Generator` consists of two fields `f` and `iter`.
This can be taken as a representation of `map(f, iter)`:

```@repl Iterators
using FixArgs

gen = let f = string, iter = 1:10
    @xquote map(f, iter)
end
```

It's certainly less nice to look at than `Base.Generator{UnitRange{Int64}, typeof(string)}(string, 1:10)`.
Better UX / ergonomics are be possible by defining a type alias:

```julia
const MyGenerator{F, I} = FixArgs.Call{Some{typeof(map)}, FixArgs.FrankenTuples.FrankenTuple{Tuple{Some{F}, Some{I}, (), Tuple{}}}
```

That is quite unsightly, and there are quite a few internals leaking out. We can use a macro instead:

```@repl Iterators
const MyGenerator{F, I} = @xquoteT map(::F, ::I)
```
It should be made convenient to defining constructors and `show` methods that correspond with the type alias.

To evaluate the call (i.e. "collect the iterator"):

```@repl Iterators
xeval(gen)
```

This example is actually circular. The evaluation of the `map` call is done in terms of `Generator`!
The [definition](https://github.com/JuliaLang/julia/blob/ef14131db321f8f5a815dd05a5385b5b27d87d8f/base/abstractarray.jl#L2328):
```julia
map(f, A) = collect(Generator(f,A))
```


The circularity would be broken by defining

```julia
function iterate(gen::(@xquoteT map(::F, ::I))) where F, I
    f = FixArgs.xeval(gen.args[1])  # not the prettiest thing right now...
    iter = FixArgs.xeval(gen.args[2])
    # ...
end
```

and might also require a separation of the purposes of `collect` and `map`. See [this issue](https://github.com/JuliaLang/julia/issues/39628).

Many types in `Base.Iterators` can be seen as lazy calls of existing functions. `Base.Iterators.Filter(flt, itr)` could be replaced with `@xquote filter(flt, itr)`.
And the dispatches done on these types to enable the existing symbolic computation,
[e.g.](https://github.com/JuliaLang/julia/blob/ef14131db321f8f5a815dd05a5385b5b27d87d8f/base/iterators.jl#L463):

```julia
reverse(f::Filter) = Filter(f.flt, reverse(f.itr))
```

`Base.Iterators.Flatten`, which [defines a convenience function]([https://github.com/JuliaLang/julia/blob/ef14131db321f8f5a815dd05a5385b5b27d87d8f/base/iterators.jl#L463)

```julia
flatten(itr) = Flatten(itr)
```

*could* be written in terms of a function `flatten` with no methods.
However, it is perhaps better seen as `@xquote reduce(vcat, it)`

## `Base.Rational`
What is `Rational` but lazy division on integers?

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


## Pure-imaginary type
In fact, the lazy call might not be valid to begin with.

## `Base.Complex`


```@meta
CurrentModule = FixArgs
DocTestSetup = quote
    using FixArgs
end
```

```@autodocs
Modules = [FixArgs]
```
