using Curry
using Curry: bind
using Test


@testset "keywords" begin
    @test bind(≈, 1, nothing, atol=1.1)(2)
    @test bind(≈, 1, nothing, )(2, atol=1.1)
    @test !bind(≈, 1, nothing, atol=1.1)(2, atol=0.9)
    @test !bind(≈, 1, nothing, atol=0.9)(2)
    @test bind(≈, 1, nothing, atol=0.9)(2, atol=1.1)
    @test bind(≈, 1, nothing, atol=0.9)(2, atol=2)

    @test bind(≈, nothing, nothing, atol=1.1)(1,2)
    @test !bind(≈, nothing, nothing, atol=0.9)(1,2)
    a2 = @inferred bind(≈, nothing, nothing)
    b2 = @inferred bind(≈, nothing, nothing, atol=1)
    c2 = @inferred bind(≈, nothing, nothing, atol=1, rtol=2)
    a1 = @inferred bind(≈, 3, nothing, atol=1, rtol=2)
    @inferred a2(1,2)
    @inferred b2(1,2)
    @inferred c2(1,2)
    @inferred a1(1.0)
end

@testset "Bind.jl" begin

    #=
    example replacement of Rational
    =#

    using Base: divgcd

    function Base.:*(x::Bind{typeof(/), Tuple{N1, D1}}, y::Bind{typeof(/), Tuple{N2, D2}}) where {N1, D1, N2, D2}
      xn, yd = divgcd(x.a[1], y.a[2])
      xd, yn = divgcd(x.a[2], y.a[1])
      @bind (xn * yn) / (xd * yd) # TODO use `unsafe_rational` and `checked_mul`
    end

    half = (@bind 1/3) * (@bind 3/2)
    @test half() == 0.5

    #=
    example deferring `Set` operations
    =#

    """Produce a "useful" bound, in the sense that `x ∈ input` implies `x ∈ result_type`"""
    function bounding(result_type, input) end

    bounding(::Type{>:UnitRange}, v::Vector{<:Integer}) = UnitRange(extrema(v)...)
    # bounding(URT::Type{UnitRange{T}}, v::Vector{<:Integer}) where T<:Integer = URT(extrema(v)...)

    function bounding(::Type{>:UnitRange}, _union::Bind{typeof(union), Tuple{UnitRange{T}, UnitRange{T}}}) where T <: Integer
        (a, b) = _union.a
        UnitRange(min(minimum(a), minimum(b)), max(maximum(a), maximum(b)))
    end

    # eagerly generates intermediate representation of `union(1:3,5:7)`
    eager = bounding(UnitRange, union(1:3,5:7))
    # use specialized method for bounding unions of `UnitRange`s
    lazy = bounding(UnitRange, @bind union(1:3,5:7))
    @test eager == lazy


    is3 = bind(==, 3, nothing)
    @test false == @inferred is3(4)
    isnothing2 = Bind(===, (Some(nothing), nothing), ())

    @test isnothing2(nothing)
    @test isnothing2(:notnothing) == false

    b = @bind "hey" * nothing * "there"
    @test b(", you, ") == "hey, you, there"
end

using Documenter: doctest
doctest(Curry)
