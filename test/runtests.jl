using Curry
using Test

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


    is3 = Bind(==, (3, nothing))
    @test false == @inferred is3(4)
    isnothing2 = Bind(===, (Some(nothing), nothing))

    @test isnothing2(nothing)
    @test isnothing2(:notnothing) == false

    b = @bind "hey" * nothing * "there"
    @test b(", you, ") == "hey, you, there"
end
