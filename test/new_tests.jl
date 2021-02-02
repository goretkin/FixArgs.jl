using Test
using FixArgs.TypedExpressions: @quote_some, @xquote

using Test: @test, @testset
expr_tests = [
    (
        (let x = 9
            @quote_some sqrt(x)
        end),
        :($(sqrt)(9))
    ),
    (
        (let x = 9, sqrt=sin
            @quote_some sqrt(x)
        end),
        :($(sin)(9))
    ),
    (
        (let x = 9
            @quote_some Base.sqrt(x)
        end),
        :($(sqrt)(9))
    ),
    (
        (let x = 9, sqrt=sin
            @quote_some Base.sqrt(x)
        end),
        :($(sqrt)(9))
    )
]

@testset "@quote_some" begin
    for t in expr_tests
        @test isequal(t[1], t[2])
    end
end

macro _test1(ex)
    quote
        ($ex, $(esc(ex)))
    end
end
# using .TypedExpressions: EscVal, all_typed, uneval
#=
_ex_1 = :(x -> ==(x, 0))
_ex_2 = :(x -> $(==)(x, 0))
_ex_3 = :(x -> $(==)(x, :zero))
_ex_4 = :(x -> $(==)(x, $(Val(0))))
_ex_5 = :(x -> $(==)(x, $(EscVal{Val(0)}())))
=#
# ex = all_typed(_ex_2)

if VERSION >= v"1.6-"
    # test alias printing
    # @test string(typeof(ex)) == "FixNew{Tuple{Val{:x}}, typeof(==), Tuple{Val{:x}, Int64}}"
end