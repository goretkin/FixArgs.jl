using FixArgs: FixArgs
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

@testset "@xquote and Fix1, Fix2" begin
    @test (@xquote x -> ==(1, x)) == FixArgs.TypedExpressions.Fix1(==, 1)
    @test (@xquote x -> ==(x, 1)) == FixArgs.TypedExpressions.Fix2(==, 1)
    @test (@xquote x -> x == 1) == FixArgs.TypedExpressions.Fix2(==, 1)
    @test (@xquote (x,) -> ==(x, 1)) == FixArgs.TypedExpressions.Fix2(==, 1)
    @test (@xquote xyz -> ==(xyz, 1)) == FixArgs.TypedExpressions.Fix2(==, 1)
    @test (let one = 1; @xquote x -> ==(x, one) end) == FixArgs.TypedExpressions.Fix2(==, 1)
    @test (let one = 1, eq = ==; @xquote x -> eq(x, one) end) == FixArgs.TypedExpressions.Fix2(==, 1)
end

@testset "compute" begin
    L = @xquote x -> ==(x, 1)
    @test true == FixArgs.TypedExpressions.xapply(L, 1)
    @test false == FixArgs.TypedExpressions.xapply(L, 2)
end

@testset "compute nested Lambda" begin
    L = @xquote x -> ( y -> ==(x, y) )
    @test FixArgs.TypedExpressions.xapply(L, 2) == FixArgs.TypedExpressions.Fix1(==, 2)
end

@testset "compute nested Call" begin
    foo = x -> (y -> (string.(1:x))[y])
    bar = z -> foo(z)(z)
    L1 = @xquote z -> foo(z)(z)
    for i = 1:5
        @test L1(i) == bar(i)
    end
end

@testset "compute nested Lambda and Call" begin
    foo = x -> (y -> (string.(1:x))[y])
    bar = z -> foo(z)(z)
    # the colon syntax  happens during lowering, which I do not know how to hook into.
    # use `UnitRange` directly
    # same with Broadcast dot notation, use `map` directly
    # same with square brackets, use `getindex` directly
    L = @xquote x -> (y -> getindex(map(string, UnitRange(1, x)), y))
    L1 = @xquote z -> L(z)(z)
    for i = 1:5
        @test L1(i) == bar(i)
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