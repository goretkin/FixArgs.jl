using Test
using FixArgs.TypedExpressions: @quote_some, @xquote, relabel_args

using Test: @test, @testset
using MacroTools: @capture

@testset "relabel_args" begin
    let ex = relabel_args(x -> x isa Symbol, x -> Symbol(string(x)), :(x -> (y -> x + y)))
        @capture ex arg1_ -> (arg2_ -> term1_ + term2_)
        @test arg1 == Symbol("(referent_depth = 1, antecedent_depth = 1, arg_i = 1, sym = :x)")
        @test arg2 == Symbol("(referent_depth = 2, antecedent_depth = 2, arg_i = 1, sym = :y)")
        @test term1 == Symbol("(referent_depth = 3, antecedent_depth = 1, arg_i = 1, sym = :x)")
        @test term2 == Symbol("(referent_depth = 3, antecedent_depth = 2, arg_i = 1, sym = :y)")
    end

    let ex = relabel_args(x -> x isa Symbol, x -> Symbol(string(x)), :((x, w) -> ((y, z) -> x + y + w + z)))
        @capture ex (arg1_, arg3_) -> ((arg2_, arg4_) -> term1_ + term2_ + term3_ + term4_)
        @test arg1 == Symbol("(referent_depth = 1, antecedent_depth = 1, arg_i = 1, sym = :x)")
        @test arg2 == Symbol("(referent_depth = 2, antecedent_depth = 2, arg_i = 1, sym = :y)")
        @test arg3 == Symbol("(referent_depth = 1, antecedent_depth = 1, arg_i = 2, sym = :w)")
        @test arg4 == Symbol("(referent_depth = 2, antecedent_depth = 2, arg_i = 2, sym = :z)")
        @test term1 == Symbol("(referent_depth = 3, antecedent_depth = 1, arg_i = 1, sym = :x)")
        @test term2 == Symbol("(referent_depth = 3, antecedent_depth = 2, arg_i = 1, sym = :y)")
        @test term3 == Symbol("(referent_depth = 3, antecedent_depth = 1, arg_i = 2, sym = :w)")
        @test term4 == Symbol("(referent_depth = 3, antecedent_depth = 2, arg_i = 2, sym = :z)")
    end
end

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