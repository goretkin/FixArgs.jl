using FixArgs: FixArgs, @xquoteT
using FixArgs: @xquote, xeval, fix, @fix
using Test: @test, @test_broken, @testset, @inferred, @test_throws

@testset "basics" begin
    @test  fix(≈, 1, nothing, atol=1.1)(2)
    #@test  fix(≈, 1, nothing, )(2, atol=1.1)
    #@test !fix(≈, 1, nothing, atol=1.1)(2, atol=0.9)
    @test !fix(≈, 1, nothing, atol=0.9)(2)
    #@test  fix(≈, 1, nothing, atol=0.9)(2, atol=1.1)
    #@test  fix(≈, 1, nothing, atol=0.9)(2, atol=2)

    @test fix(≈, nothing, nothing, atol=1.1)(1,2)
    @test !fix(≈, nothing, nothing, atol=0.9)(1,2)

    @test  (@fix ≈(1, _, atol=1.1))(2)
    #@test  (@fix ≈(1, _)          )(2, atol=1.1)
    #@test !(@fix ≈(1, _, atol=1.1))(2, atol=0.9)
    @test !(@fix ≈(1, _, atol=0.9))(2)
    #@test  (@fix ≈(1, _, atol=0.9))(2, atol=1.1)
    #@test  (@fix ≈(1, _, atol=0.9))(2, atol=2)
    @test  (@fix ≈(_, _, atol=1.1))(1,2)
    @test !(@fix ≈(_, _, atol=0.9))(1,2)

    x = "hello"
    @test @fix(identity(_))(x) === x
    xs = [1, 2]
    @test @fix(+(_, xs...))(2) === 2 + 1 + 2
    @test @fix(_ + 1 + _)(2,2) === 2 + 1 + 2

    kw = (atol=1, rtol=0)
    @test  (@fix ≈(_,_;kw...))(1,2)
    @test !(@fix ≈(_,_;kw...))(1,2.1)

    f(args...; kw...) = (args, kw.data)
    @test (@fix f(1, _, 3, x=1, y=2))(2) === ((1,2,3),(x=1,y=2))
    kw = (x=1, y=42)
    #@test (@fix f(1, _, 3; kw...))(2, y=2) === ((1,2,3),(x=1,y=2))


    a2 = @inferred fix(≈, nothing, nothing)
    b2 = @inferred fix(≈, nothing, nothing, atol=1)
    c2 = @inferred fix(≈, nothing, nothing, atol=1, rtol=2)
    a1 = @inferred fix(≈, Some(3), nothing, atol=1, rtol=2)
    @inferred a2(1,2)
    @inferred b2(1,2)
    @inferred c2(1,2)
    @inferred a1(1.0)


    @test_throws Exception @fix(_ + _)(1, 2, 3)
    @test_throws Exception @fix(_ + _)(1)
end

#=
@testset "fix(::Type, ...)" begin
    f = @inferred fix(CartesianIndex, nothing, Some(1))
    @test @inferred(f(2)) === CartesianIndex(2, 1)

    modulo(x; by) = mod(x, by)
    g = @inferred fix(modulo, nothing, by = UInt8)
    @test_broken @inferred(g(271)) === 0x0f
end
=#

@testset "`Rational` as lazy `/``" begin

    #=
    example replacement of Rational
    =#

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

    half = (@xquote 1/3) * (@xquote 3/2)
    @test xeval(half) == 0.5
    half = (@xquote $(UInt64(1)) / $(UInt64(3))) * (@xquote $(UInt64(3)) / $(UInt64(2)))
    @test xeval(half) == 0.5

    @test typeof(@xquote union($([1]), $([2]))) == @xquoteT union(::Vector{Int64}, ::Vector{Int64})
end

@testset "lazy `union`" begin
    #=
    example deferring `Set` operations
    =#

    # TODO attach a docstring to a function, without defining a method.
    #=
    """Produce a "useful" bound, in the sense that `x ∈ input` implies `x ∈ result_type`"""
    function bounding(result_type, input)
        # this function exists just so that the docstring can be attached to the generic function
        throw(MethodError("implement me"))
    end
    =#

    """Produce a "useful" bound, in the sense that `x ∈ input` implies `x ∈ result_type`"""
    bounding(::Type{>:UnitRange}, v::Vector{<:Integer}) = UnitRange(extrema(v)...)
    # bounding(URT::Type{UnitRange{T}}, v::Vector{<:Integer}) where T<:Integer = URT(extrema(v)...)

    function bounding(
            ::Type{>:UnitRange},
            _union::(@xquoteT union(::UnitRange{T}, ::UnitRange{T}))
           ) where T <: Integer
        (a, b) = something.(_union.args)
        UnitRange(min(minimum(a), minimum(b)), max(maximum(a), maximum(b)))
    end

    # eagerly generates intermediate representation of `union(1:3,5:7)`
    eager = bounding(UnitRange, union(1:3,5:7))
    # use specialized method for bounding unions of `UnitRange`s
    lazy = bounding(UnitRange, @xquote union($(1:3),$(5:7)))
    @test eager == lazy

    @test_throws MethodError bounding(UnitRange, @xquote union($(1:3),$(5:7); a_kwarg=:unsupported))

    r1 = UInt64(1):UInt64(3)
    r2 = UInt64(5):UInt64(7)
    eager = bounding(UnitRange, union(r1,r2))
    lazy = bounding(UnitRange, @xquote union(r1,r2))
    @test eager == lazy
end

@testset "escaping and etc" begin
    is3 = fix(==, Some(3), nothing)
    @test false == @inferred is3(4)
    isnothing2 = fix(===, Some(nothing), nothing)

    @test isnothing2(nothing)
    @test isnothing2(:notnothing) == false

    b = @fix "hey" * _ * "there"
    @test b(", you, ") == "hey, you, there"
end

@testset "lazy `reduce(vcat, ...)`" begin
    # A watered-down version of `LazyArrays.Vcat`:
    # https://github.com/JuliaArrays/LazyArrays.jl/blob/dff5924cd8b52c62a34cce16372381bb8a9e35cb/src/lazyconcat.jl#L11

    # TODO generalie to `AbstractVector`
    # T_reduce_vcat_vector{T} = (@xquoteT reduce(::typeof(vcat), ::AbstractVector{<:AbstractVector{T}}))
    T_reduce_vcat_vector{T} = (@xquoteT reduce(::typeof(vcat), ::Vector{Vector{T}}))

    _vec_of_vec(reduce_vcat) = something(reduce_vcat.args[2])

    function Base.length(reduce_vcat::T_reduce_vcat_vector{T}) where {T}
        sum(length.(_vec_of_vec(reduce_vcat)))
    end

    function Base.getindex(reduce_vcat::T_reduce_vcat_vector{T}, i::Integer) where {T}
        # TODO validate that all `Vector`s start with index `1`
        vec_of_vec = _vec_of_vec(reduce_vcat)
        lengths = length.(vec_of_vec)
        cum_lengths = cumsum(lengths)
        i_outer = searchsortedfirst(cum_lengths, i)
        i_inner = i - (i_outer > 1 ? cum_lengths[i_outer-1] : 0)
        return vec_of_vec[i_outer][i_inner]
    end

    ref = reduce(vcat, [[:a, :b, :c], [:d, :e]])
    laz = @xquote reduce(vcat, [[:a, :b, :c], [:d, :e]])

    @test length(ref) == length(laz)
    for i = 1:length(ref)
        @test ref[i] == laz[i]
    end
end

@testset "Fixed Point Numbers as lazy `/` with static denominator" begin
    # e.g. Fixed{Int8,7} from `FixedPointNumbers.jl`
    MyQ0f7_instance = (@xquote $(Int8(3)) / 128::::S)
    MyQ0f7 = typeof(MyQ0f7_instance)
    @test MyQ0f7 === (@xquoteT ::Int8 / 128::::S)

    Fixed{N,D} = @xquoteT ::N / D::::S
    function Base.:+(a::Fixed{N,D}, b::Fixed{N,D})::Fixed{N,D} where {N, D}
        n = something(a.args[1]) + something(b.args[1])
        return (@xquote $(N(n)) / D::::S)
    end

    @test xeval(MyQ0f7_instance + MyQ0f7_instance) === 6/128
    @test sizeof(MyQ0f7) == sizeof(Int8)
end

@testset "imaginary unit as lazy and static *, and `Complex` as lazy +, using `reinterpret`" begin
    # This example is a bit circular, since `im` is already `Complex`. But suppose there were some `ImaginaryUnit()` singleton.
    # the "besides the point" evaluations would fail, but the overall point stands that:
    # 1. imaginary numbers can be representeded with lazy multiplication with `ImaginaryUnit()`
    # 2. complex numbers can be represented with lazy addition of real numbers and imaginary numbers

    typed_data = [i + 10*i*im for i = 1:10]
    untyped_data = reinterpret(Int, typed_data)

    MyComplex_instance = @xquote 1 + 2 * im::::S

    # that this works is kind of besides the point
    @test xeval(MyComplex_instance) === 1 + 2im

    # the point is that `MyComplex` is a memory representation of a complex number made from two `Int`s
    # `MyComplex` is just an alias for the structure of the type
    MyComplex = typeof(MyComplex_instance)

    new_typed_data = reinterpret(MyComplex, untyped_data)
    @test map(xeval, new_typed_data) == typed_data     # again, kind of besides the point

    # note that there are other structures possible which would give the same results
    # for example `im::::S * 2` instead of `2 * im::::S` gives a different structure with the same result
    # swapping the arguments to `+` would give a different memory layout.

    # the point is also that you could define `*(::MyComplex, ::MyComplex)::MyComplex`
    # and that you can do so without introducing any new type names
end

@testset "calls and not calls" begin
    # These errors are thrown at macro expansion time.
    @test_throws Exception eval(:(@fix "not a call $(_)"))
    @test_throws Exception eval(:(@fix (:not_a_call, _)))
    if VERSION ≥ v"1.5"
        @test_throws Exception eval(:(@fix (;a=:not_a_call, b=_)))
    end

    fs = @fix string("a call ", _)
    ft = @fix tuple(:a_call, _)
    fnt = @xquote x -> NamedTuple{(:a, :b)}(tuple(:a_call, x))

    @test fs(4) == "a call 4"
    @test ft(4) == (:a_call, 4)
    @test fnt(4) ==  NamedTuple{(:a, :b)}((:a_call, 4))
end

function isinferred(f, arg_types)
    Ts = Base.return_types(f, arg_types)
    return length(Ts) == 1 && isconcretetype(only(Ts))
end

@testset "repeat arguments" begin
    foo = @xquote (_1, _2, _3, _4, _5) -> tuple(_1, _2, _5, (string(_1, _3, _4)))
    @test foo(:a, :b, "c", 1, 2.0) == (:a, :b, 2.0, "ac1")
    @test isinferred(foo, (Symbol, Symbol, String, Int64, Float64))

    # not enough args
    @test !isinferred(foo, (Symbol, Symbol, String, Int64))

    # error on extra args
    @test_throws Exception foo(:a, :b, "c", 1, 2.0, :extra) == (:a, :b, 2.0, "ac1")
end

@testset "nested function definitions" begin
    foo = x -> (y -> *(x, y))
    foo1 = @xquote x -> (y -> *(x, y))

    @test foo("a")("b") == foo1("a")("b")
end

using Documenter: DocMeta, doctest

# implicit `using FixArgs` in every doctest
DocMeta.setdocmeta!(FixArgs, :DocTestSetup, :(using FixArgs); recursive=true)

doctest(FixArgs)
