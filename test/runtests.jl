using FixArgs
using Test

@testset "basics" begin
    @test  fix(≈, 1, nothing, atol=1.1)(2)
    @test  fix(≈, 1, nothing, )(2, atol=1.1)
    @test !fix(≈, 1, nothing, atol=1.1)(2, atol=0.9)
    @test !fix(≈, 1, nothing, atol=0.9)(2)
    @test  fix(≈, 1, nothing, atol=0.9)(2, atol=1.1)
    @test  fix(≈, 1, nothing, atol=0.9)(2, atol=2)

    @test fix(≈, nothing, nothing, atol=1.1)(1,2)
    @test !fix(≈, nothing, nothing, atol=0.9)(1,2)

    @test  (@fix ≈(1, _, atol=1.1))(2)
    @test  (@fix ≈(1, _)          )(2, atol=1.1)
    @test !(@fix ≈(1, _, atol=1.1))(2, atol=0.9)
    @test !(@fix ≈(1, _, atol=0.9))(2)
    @test  (@fix ≈(1, _, atol=0.9))(2, atol=1.1)
    @test  (@fix ≈(1, _, atol=0.9))(2, atol=2)
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
    @test (@fix f(1, _, 3; kw...))(2, y=2) === ((1,2,3),(x=1,y=2))

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

@testset "@fix object structure" begin
    f(args...;kw...) = args, kw
    o = @fix f(1,2)
    @test o.f    === f
    @test o.args === (Some(1), Some(2))
    @test o.kw   === NamedTuple()
    @test typeof(o) === Fix{typeof(o.f), typeof(o.args), typeof(o.kw)}

    o = @fix f(1,_, a=1, b=2.3)
    @test o.f    === f
    @test o.args === (Some(1), nothing)
    @test o.kw   === (a=1, b=2.3)
    @test typeof(o) === Fix{typeof(o.f), typeof(o.args), typeof(o.kw)}

    o = @fix 1 + _
    @test o.f    === +
    @test o.args === (Some(1), nothing)
    @test o.kw   === NamedTuple()
    @test typeof(o) === Fix{typeof(o.f), typeof(o.args), typeof(o.kw)}

    arr = [1,2]
    o = @fix sum(arr; dim=1)
    @test o.f    === sum
    @test o.args === (Some(arr),)
    @test o.kw   === (dim=1,)
    @test typeof(o) === Fix{typeof(o.f), typeof(o.args), typeof(o.kw)}
end

@testset "fix(::Type, ...)" begin
    f = @inferred fix(CartesianIndex, nothing, Some(1))
    @test @inferred(f(2)) === CartesianIndex(2, 1)

    modulo(x; by) = mod(x, by)
    g = @inferred fix(modulo, nothing, by = UInt8)
    @test_broken @inferred(g(271)) === 0x0f
end

@testset "`Rational` as lazy `/``" begin

    #=
    example replacement of Rational
    =#

    using Base: divgcd

    function Base.:*(
            x::Fix{typeof(/),Tuple{Some{T},Some{T}},NamedTuple{(),Tuple{}}},
            y::Fix{typeof(/),Tuple{Some{T},Some{T}},NamedTuple{(),Tuple{}}},
           ) where {T}
        xn, yd = divgcd(something(x.args[1]), something(y.args[2]))
        xd, yn = divgcd(something(x.args[2]), something(y.args[1]))
        ret = @fix (xn * yn) / (xd * yd) # TODO use `unsafe_rational` and `checked_mul`
        ret
    end

    half = (@fix 1/3) * (@fix 3/2)
    @test half() == 0.5
    half = (@fix UInt64(1)/UInt64(3)) * (@fix UInt64(3)/UInt64(2))
    @test half() == 0.5

    @test typeof(FixArgs.@fix union([1], [2])) == FixArgs.@FixT union(::Vector{Int64}, ::Vector{Int64})
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
            _union::(@FixT union(::UnitRange{T}, ::UnitRange{T}))
           ) where T <: Integer
        (a, b) = something.(_union.args)
        UnitRange(min(minimum(a), minimum(b)), max(maximum(a), maximum(b)))
    end

    # eagerly generates intermediate representation of `union(1:3,5:7)`
    eager = bounding(UnitRange, union(1:3,5:7))
    # use specialized method for bounding unions of `UnitRange`s
    lazy = bounding(UnitRange, @fix union(1:3,5:7))
    @test eager == lazy

    @test_throws MethodError bounding(UnitRange, @fix union(1:3,5:7; a_kwarg=:unsupported))

    r1 = UInt64(1):UInt64(3)
    r2 = UInt64(5):UInt64(7)
    eager = bounding(UnitRange, union(r1,r2))
    lazy = bounding(UnitRange, @fix union(r1,r2))
    @test eager == lazy


    is3 = fix(==, Some(3), nothing)
    @test false == @inferred is3(4)
    isnothing2 = Fix(===, (Some(nothing), nothing), ())

    @test isnothing2(nothing)
    @test isnothing2(:notnothing) == false

    b = @fix "hey" * _ * "there"
    @test b(", you, ") == "hey, you, there"
end

@testset "lazy `reduce(vcat, ...)`" begin
    # A watered-down version of `LazyArrays.Vcat`:
    # https://github.com/JuliaArrays/LazyArrays.jl/blob/dff5924cd8b52c62a34cce16372381bb8a9e35cb/src/lazyconcat.jl#L11

    # TODO generalie to `AbstractVector`
    # T_reduce_vcat_vector{T} = (@FixT reduce(::typeof(vcat), ::AbstractVector{<:AbstractVector{T}}))
    T_reduce_vcat_vector{T} = (@FixT reduce(::typeof(vcat), ::Vector{Vector{T}}))

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
    laz = @fix reduce(vcat, [[:a, :b, :c], [:d, :e]])

    @test length(ref) == length(laz)
    for i = 1:length(ref)
        @test ref[i] == laz[i]
    end
end

@testset "nested fix" begin
    nested = (Fix(/, ((Fix(+, (nothing, nothing), NamedTuple())), nothing), NamedTuple()))
    @test nested((1,2), 3) === 1.0
    @test (@inferred nested((1,2), 3)) === 1.0

    @test_throws Exception nested()
    @test_throws Exception nested(1)
    @test_throws Exception nested(1, 2)
    @test_throws Exception nested(1, 2, 3)
    @test_throws Exception nested((1, 2, 4), 3)
    @test_throws Exception nested((1, 2), 3, 5)
    @test_throws Exception nested((1,), 3)
    @test_throws Exception nested((), 3)

    not_nested = (Fix(/, (Some(Fix(+, (nothing, nothing), NamedTuple())), nothing), NamedTuple()))
    @test_throws MethodError not_nested(1)

    @test (@fix (@fix _ + _) / _) === nested
    @test (@fix Some(@fix _ + _) / _) === not_nested
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
    fnt = @fix NamedTuple{(:a, :b)}(@fix tuple(:a_call, _))

    @test fs(4) == "a call 4"
    @test ft(4) == (:a_call, 4)
    @test fnt((4,)) ==  NamedTuple{(:a, :b)}((:a_call, 4))
    # TODO since `4` can be splat (`Number` defines `iterate`), this does not error.
    @test fnt(4) ==  NamedTuple{(:a, :b)}((:a_call, 4))
end

using Documenter: DocMeta, doctest

# implicit `using FixArgs` in every doctest
DocMeta.setdocmeta!(FixArgs, :DocTestSetup, :(using FixArgs); recursive=true)

doctest(FixArgs)
