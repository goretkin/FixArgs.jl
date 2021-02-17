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
there aren't many methods [in the Julia ecosystem](https://juliahub.com/ui/RepoSearch?q=%3A%3A%28Base%5C.%29%3FFix%5B12%5D&r=true).

But these types are constructed with, for example, `==(3)` or `in([1, 2, 3])`.
A type like these is useful as a predicate to pass to higher-order functions, e.g. `findfirst(==(3), some_array)` to find the first element that equals `3`.
Brevity aside, these types are useful to define more efficient methods of generic higher-order functions.
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
   - a [`Lambda`](@ref) to represent function (`args -> body`)
   - a [`Call`](@ref) to represent the function *call* (`f(...)`) in the body
   - a [`ArgPos`](@ref) to represent the `x` in the body of the lambda function

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


Breaking this circularity is possible by defining

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

`Base.Iterators.Flatten`, which [defines a convenience function](https://github.com/JuliaLang/julia/blob/ef14131db321f8f5a815dd05a5385b5b27d87d8f/base/iterators.jl#L463)

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
```

```@repl Rational
using FixArgs

(@xquote 1/9) * (@xquote 3/2)
```

Of course, we have to do some more work.

```@example Rational
using Base: divgcd

function Base.:*(
        x::(@xquoteT ::T / ::T),
        y::(@xquoteT ::T / ::T),
        ) where {T}
    xn, yd = divgcd(something(x.args[1]), something(y.args[2]))
    xd, yn = divgcd(something(x.args[2]), something(y.args[1]))
    ret = @xquote $(xn * yn) / $(xd * yd) # TODO use `unsafe_rational` and `checked_mul`
    ret
end
```

Now, try again:

```@repl Rational
q = (@xquote 1/9) * (@xquote 3/2)
map(xeval, q.args) # make numerator and denominator plainly visible
```

compare with using `//` to construct a `Base.Rational`:
```@repl Rational
1//9 * 3//2
```

Finally, because we have encoded the relationship between this "new" rational type, and `/`, we can do:
```@repl Rational
xeval(q)
```

We could define an alias:
```@example Rational
const MyRational{T} = @xquoteT(::T / ::T)
```

which would also enforce the same type for both the numerator and denominator, as is the case of `Base.Rational`.

```@repl Rational
sizeof(MyRational{Int32})
```

Occasionally, a user might find this to be a limitation, yet they would still like to use some of the generic algorithms that might apply.

The fields of `Base.Rational` are `num` and `den`.
They have to be named since there is nothing else that gives the fields any meaning at all.
In our type, however, they can be distinguished by the role they play with respect to the `/` function.

## Fixed-Point Numbers and "static" arguments
A fixed-point number is just a rational number with a specified denominator.
If we have a large array of fixed-point numbers with the same denominator, we certainly do not want to store the denominator repeatedly.

And we also want to efficient code to be generated for arithmetic.

So we can "bake in" some values (see `Base.isbitstype`) into the type of `Call` itself!

In other words, what is a fixed-point number but lazy division with a static denominator?
Here is an example that models `Fixed{Int8,7}` from [`FixedPointNumbers.jl`](https://github.com/JuliaMath/FixedPointNumbers.jl).
The macros use the notation `V::::S` to mark an argument `V` as "static".
Also note the use of `$` to escape subexpressions.

```@repl FixedPoint
using FixArgs

MyQ0f7(x) = (@xquote $(Int8(x)) / 128::::S)     # hide
MyFixed{N,D} = @xquoteT ::N / D::::S              # hide
MyFixed{Int8, 128} === typeof(MyQ0f7(3))

function Base.:+(a::MyFixed{N,D}, b::MyFixed{N,D})::MyFixed{N,D} where {N, D}
    n = something(a.args[1]) + something(b.args[1])
    return (@xquote $(N(n)) / D::::S)
end

xeval(MyQ0f7(3) + MyQ0f7(2)) === 5/128
```

```@repl FixedPoint
sizeof(MyFixed{Int8, 128})
sizeof(Int8)
```

And the generated code appears to be equivalent between

```julia
using FixedPointNumbers
look_inside_1(x, y) = reinterpret(Fixed{Int8, 7}, Int8(x)) + reinterpret(Fixed{Int8, 7}, Int8(y))
```

and
```julia
look_inside_2(x, y) = MyQ0f7(x) + MyQ0f7(y)
```

## Pure-imaginary type and `Base.Complex`
Now that we can make some arguments static, we can introduce a meaningful example where the lazy call might not be valid to begin with.
You can define a type such that `xeval` raises `MethodError` and still represent the computation symbolically.
You can define a type `A` in terms of a function `f` and a type `B` even if it may not make sense to define a new method of `f` on `B`.

Here is an over-the-top example:

```@repl Imaginary
using FixArgs

struct ImaginaryUnit end    # if we want to be really cute, can do `@xquote sqrt((-1)::::S)`
const Imaginary{T} = @xquoteT ::T * ::ImaginaryUnit
Imaginary(x) = @xquote x * $(ImaginaryUnit())   # note escaping
```

note that if we assume we have no `Base.Complex` or anything like it, we don't have a way to further evaluate:
```@repl Imaginary
xeval(Imaginary(3))
```

We represented pure imaginary numbers as lazy multiplication of numbers and a singleton type `ImaginaryUnit`, and it is basically as if we had defined

```
struct Imaginary{T}
    _::T
end
```

Let's just go ahead and represent complex numbers too:

```@repl Imaginary
# const MyComplex{R, I} = @xquoteT ::R + (::I * ::ImaginaryUnit) # TODO this macro doesn't work
MyComplex(r, i) = @xquote r + i * $(ImaginaryUnit())
```

Note this monster of a type has the same size as `Base.Complex`:

```@repl Imaginary
sizeof(Complex(1, 2))
sizeof(MyComplex(1, 2))
```

and the same layout too:
```@repl Imaginary
reinterpret(Int64, [Complex(1, 2)])
reinterpret(Int64, [MyComplex(1, 2)])
```

Of course, there are many different types that would all be mathematically equivalent by swapping the arguments to `+` or `*`.
Note that swapping the arguments to `+` would give a different memory layout.

## Faster set operations by deferring computation
Suppose we have some generic function to return bounds on set-like objects.

```@example Sets

"""Produce the unique best bound, in the sense that `x ∈ input` implies `x ∈ result`"""
function bounding#=(result_type, input)=# end
```

The objects may be shapes in space, and `result_type` could correspond to important categories of bounding volumes.
To keep things simple, let us deal with sets of integers as represented by e.g. `Vector` and `UnitRange`.

```@repl Sets
bounding(::Type{UnitRange}, v::Vector{<:Integer}) = UnitRange(extrema(v)...)

bounding(UnitRange, [1, 3, 5])
```

Consider the following computation:
```@repl Sets
eager = bounding(UnitRange, union(1:3, 5:7))
```

It might be worth deferring that `union` call.
It produces a representation with a size linear in the number of elements, whereas a deferred computation is  representable in constant size.

```@example Sets
using FixArgs

function bounding(
        ::Type{UnitRange},
        _union::(@xquoteT union(::UnitRange{T}, ::UnitRange{T}))
        ) where T <: Integer
    (a, b) = something.(_union.args)
    UnitRange(min(minimum(a), minimum(b)), max(maximum(a), maximum(b)))
end
```

Now to use our specialized method for bounding unions of `UnitRanges`, we simply defer one part of the previous computation:
```@repl Sets
lazy = bounding(UnitRange, @xquote union($(1:3),$(5:7)))
eager == lazy
```

## Ergonomics and Syntax
Ideally, this package would support exactly the syntax that Julia supports.
However, it is a bit challenging not being able to hook into lowering exactly.
- <https://docs.julialang.org/en/v1/devdocs/ast/#Bracketed-forms>
- <https://github.com/JuliaLang/julia/pull/32201>

Anonymous function syntax is still under discussion:
- <https://github.com/JuliaLang/julia/issues/38713>
- <https://github.com/JuliaLang/julia/pull/24990>

There are packages that define anonymous function syntax, and it would be nice to ensure that they compose with e.g. `@xquote`.
- <https://c42f.github.io/Underscores.jl/stable/#Reference-1>

# Philosophy
## Names
(see also [nominative and structural type systems](https://en.wikipedia.org/wiki/Structural_type_system))

The Julia ecosystem goes to great lengths to find the right generic functions and to ensure that all methods defined on generic functions are semantically compatible.
This effort enables generic programming and interoperability.
Much care goes into naming these functions and deciding their generic meaning, and it makes sense to reuse those names when possible,
instead of creating a new name.

One possible advantage of using compositional names for types is that two packages can declare methods on the same type without knowing about each other,
as long as both packages know about the constituents of the composition.
There may be situations in which using a compositional name is a better strategy than trying to establish a "FooBase" package.

It is certainly possible to go overboard, however.
## Type Piracy
The Julia manual discusses [not overloading methods on container types](https://docs.julialang.org/en/v1/manual/style-guide/#Don't-overload-methods-of-base-container-types) defined by others ([hashed](https://github.com/JuliaLang/julia/blob/ef3c20d49ad96d5ce1aa24f5d0e0766c64283f28/doc/src/manual/style-guide.md#dont-overload-methods-of-base-container-types)).

Arguably [`Call`](@ref) can be seen as a container type, but the whole purpose of it is for methods to be defined on it.
As far as type piracy is concerned, e.g.  `@xquoteT ::Int64 / ::Int64`  is equivalent to using `Rational{Int64}` since in both cases, all types are owned by `Base` (assuming `Call`, `Lambda`, etc. is not owned by your package (module) either). In this example, the types are `typeof(/)` and `Int64`.

For a function owned by your package, e.g. `my_foo`, by all means define `my_foo(::(@xquoteT ::Int64 / ::Int64))`.

For a function not owned your package, e.g. `Base.:*`, to avoid type piracy, `*` should be defined by a package that owns at least one of the constituent types, e.g.
- `Base.:*(::(@xquote MyFunction(::NotMyType))`
- `Base.:*(::(@xquote NotMyFunction(::MyType))`
- `Base.:*(::(@xquote MyFunction(::MyType))`

If it is controversial what `f(::(@xquoteT func(::A, ::B)` should mean, then it is likely worth defining a new type instead of using this package.

If there are multiple functions that apply to the fields of a struct, as in:

```julia
struct MyType{T1, T2}
    arg1::T1
    arg2::T2
end

f1(t::MyType) = *(t.arg1, t.arg2)
f2(t::MyType) = +(t.arg1, t.arg2)
```

Then it also seems like type would also not be a good candidate to be replaced with a `Call`. Which of `*` or `+` would one choose?

# More examples
## Types of geometry primitives from scratch
What is better?
```julia
struct Disc{R, C}
    radius::R
    center::C
end
```

or

```julia
using LinearAlgebra: norm
Disc(r, c) = @xquote x -> norm(x - c) ≤ r
```

Honestly, I don't know. I imagine there is a trade-off.
But consider a situation where you'd like to distinguish between the disc with boundary, disc without boundary, and just the boundary (a circle).
Those distinctions are as simple as `≤`, `<`, and `==`.
You might more accurately call the struct above `DiscWithBoundary`, and introduce `DiscWithoutBoundary` and `Circle`.
Or instead you might use a convention that all the regions are closed sets and introduce wrapper types `WithoutBoundary` and `OnlyBoundary`.
In both cases, there's a lot of names to choose...

## A way to avoid naming a new method
Computing the square norm of a vector can usually be done more efficiently than computing the norm and then computing the square.

```@repl NormSquared
using FixArgs
using LinearAlgebra: norm, norm_sqr
vec = [1, 1]
```

instead of writing
```@repl NormSquared
norm_sqr(vec)
```

maybe you would rather write

```@repl NormSquared
xeval(@xquote norm(vec)^2::::S)
```

Well, perhaps better with an alternative macro that applies `::::S` to any `isbitstype` literals, and also does `xeval`.
```
@a_good_short_name norm(vec)^2
```
Whatever owns `norm` can add a new method to `xeval` to detect this form and use the more efficient method.

```julia
xeval(c::(@xquoteT norm(::T)^2::::S)) where T = norm_sqr(c.args[1].args[1])
```

This is different from having a package define its own macro.
This would be one macro that can be hooked into by defining new methods on `xeval`.

## Alternative to `Base.literal_pow`
```@repl
Meta.@lower x^2
```

Could instead lower to roughly
```
%1 = @xquote x^(2::::S) # i.e. something roughly like `Call(^, x, Val(2))`
%2 = xeval(%1)
```

`xeval` could call `Base.literal_pow` for [backwards compatibility](https://juliahub.com/ui/CodeSearch?q=literal_pow&u=define&t=all;):

```@repl LiteralPow
using FixArgs
function FixArgs.xeval(x::(@xquoteT (::B)^(E::::S))) where {B, E}
    println("I was called")
    base = xeval(x.args[1])
    Base.literal_pow(^, base, Val(E))
end

let x = 3
    xeval(@xquote x^(2::::S))
end
```

but going forward, types that wish to hook into this functionality would define a method on `xeval` directly.

## Related Patterns and Possible Applications:

[Base.Broadcast.Broadcasted](https://github.com/JuliaLang/julia/blob/d06c2a97be3f643d403c4069955e135823ff9fd0/base/broadcast.jl#L152-L173) is like [`Call`](@ref) with extra information `Style` and `axes::Axes`.
`materialize` is like `xeval`.
There's more information in the [manual](https://docs.julialang.org/en/v1/manual/interfaces/#extending-in-place-broadcast).

[Base.Generator](https://github.com/JuliaLang/julia/blob/676ccf4eaa9b6e6c6a53f75abb4bf3e1a2457426/base/generator.jl#L3-L34), as already discussed.


### partial application with keyword arguments
[Definition](https://github.com/JuliaLang/julia/blob/ce5bd1c3dadcc7c733508a19a4b692b744d59a3d/base/floatfuncs.jl#L288)
```julia
isapprox(y; kwargs...) = x -> isapprox(x, y; kwargs...)
```

probably would use `Base.Fix2` if it also supported keyword arguments. All other docstrings with "Create a function" do.

### array-of-struct and struct-of-array representations
[StructArrays.jl](https://github.com/JuliaArrays/StructArrays.jl)
```@example

soa = (a=[1,2,3], b=[10, 20, 30])
aos_eager = map(NamedTuple{(:a, :b)} ∘ tuple, soa.a, soa.b)
```

### non-standard evaluation
<https://discourse.julialang.org/t/approximating-non-standard-evaluation-like-in-r-e-g-for-plot-labels/41889/10>

### nominal vs structural fields
<https://github.com/JuliaLang/julia/pull/37517/files>
Instead of field names `inner` and `outer`, the arguments can be distinguished by the role they play with respect to the function `∘`.

What if `∘` itself is defined as `∘(a, b) = @xquote a ∘ b`?
Then define function without methods: `function ∘ end`

# Concerns
The poor compiler...

The poor user trying to understand the error message...

Method ambiguities

Unifying too many things can lead to too much coupling.

# API and internals

```@meta
CurrentModule = FixArgs
DocTestSetup = quote
    using FixArgs
end
```

```@autodocs
Modules = [FixArgs]
```
