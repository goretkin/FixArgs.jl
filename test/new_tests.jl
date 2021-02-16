using FixArgs: FixArgs
using FixArgs: @quote_some, @xquote, relabel_args
using Test: @test, @test_broken, @testset, @inferred, @test_throws
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
    @test (@xquote x -> ==(1, x)) == FixArgs.Fix1(==, 1)
    @test (@xquote x -> ==(x, 1)) == FixArgs.Fix2(==, 1)
    @test (@xquote x -> x == 1) == FixArgs.Fix2(==, 1)
    @test (@xquote (x,) -> ==(x, 1)) == FixArgs.Fix2(==, 1)
    @test (@xquote xyz -> ==(xyz, 1)) == FixArgs.Fix2(==, 1)
    @test (let one = 1; @xquote x -> ==(x, one) end) == FixArgs.Fix2(==, 1)
    @test (let one = 1, eq = ==; @xquote x -> eq(x, one) end) == FixArgs.Fix2(==, 1)
end

@testset "compute" begin
    L = @xquote x -> ==(x, 1)
    @test true == FixArgs.xapply(L, (1, ))
    @test false == FixArgs.xapply(L, (2, ))
end

@testset "compute nested Lambda" begin
    L = @xquote x -> ( y -> ==(x, y) )
    @test FixArgs.xapply(L, (2, )) == FixArgs.Fix1(==, 2)

    Lxyz = @xquote x -> y -> z -> (x * y * z)
    @test Lxyz("a")("b")("c") == "abc"
end

@testset "compute nested Call" begin
    foo = x -> (y -> (string.(1:x))[y])
    bar = z -> foo(z)(z)
    Xbar = @xquote z -> foo(z)(z)
    for i = 1:5
        @test Xbar(i) == bar(i)
    end
end

@testset "compute nested Lambda and Call" begin
    foo = x -> (y -> (string.(1:x))[y])
    bar = z -> foo(z)(z)
    # the colon syntax  happens during lowering, which I do not know how to hook into.
    # use `UnitRange` directly
    # same with Broadcast dot notation, use `map` directly
    # same with square brackets, use `getindex` directly
    Xfoo = @xquote x -> (y -> getindex(map(string, UnitRange(1, x)), y))
    Xbar = @xquote z -> Xfoo(z)(z)
    for i = 1:5
        @test Xbar(i) == bar(i)
    end
end

@testset "printing" begin
    Xfoo = @xquote x -> (y -> getindex(map(string, UnitRange(1, x)), y))
    Xbar = @xquote z -> Xfoo(z)(z)
    L = @xquote x -> ( y -> ==(x, y) )
    Lxyz = @xquote x -> y -> z -> (x * y * z)

    # for now, just check this doesn't generate errors.
    println(stdout, Xfoo)
    println(stdout, Xbar)
    println(stdout, L)
    println(stdout, Lxyz)
    @test true
end

@testset "type macro" begin
    @test (FixArgs.@xquoteT string(::Int64)) === typeof(@xquote string(3))
    v = @xquote string(1, 2::::S, (:three), (:four)::::S)
    t = FixArgs.@xquoteT string(::Int64, 2::::S, ::Symbol, (:four)::::S)
    @test t === typeof(v)
end

@testset "static argument" begin
    @test 3 === FixArgs.xeval(FixArgs.Call(Some(+), FixArgs.FrankenTuple((Some(1), Val(2)), NamedTuple())))
    frac = @xquote 1 / 2
    frac2 = @xquote 1 / 2::::S
    @test FixArgs.xeval(frac) === 1 / 2
    @test FixArgs.xeval(frac2) === 1 / 2
    @test sizeof(frac) == 16
    @test sizeof(frac2) == 8
end

@testset "xquote syntax" begin
    # any expression head that is not anticipated is escaped.
    # such as `tuple`, `vect`, `vcat`, `hcat`

    # Here's a list of some forms:
    # https://github.com/JuliaLang/julia/blob/ef14131db321f8f5a815dd05a5385b5b27d87d8f/doc/src/devdocs/ast.md#bracketed-forms

    # other macros and functions have to deal with this too:
    # https://github.com/JuliaLang/julia/blob/ef14131db321f8f5a815dd05a5385b5b27d87d8f/stdlib/InteractiveUtils/src/macros.jl#L136
    # https://github.com/JuliaLang/julia/blob/ef14131db321f8f5a815dd05a5385b5b27d87d8f/base/show.jl#L1721

    # and there are occasionally updates:
    # https://github.com/JuliaLang/julia/pull/28122

    tuple1 = @xquote x -> (1, x)
    @test_broken tuple1(2) == (1, 2)

    vect1 = @xquote x -> [1, x]
    @test_broken tuple1(2) == [1, 2]

    vcat1 = @xquote x -> [1; x]
    @test_broken tuple1(2) == [1; 2]

    hcat1 = @xquote x -> [1 x]
    @test_broken tuple1(2) == [1 2]

    vcat_row1 = @xquote x -> [1 x; 3 4]
    @test_broken tuple1(2) == [1 2; 3 4]

    @test_throws Exception FixArgs.@xquote x -> x.a
end

@testset "@xquoteT errors" begin
    @test_throws Exception macroexpand(Main, :(FixArgs.@xquoteT x -> x))
    @test_throws Exception macroexpand(Main, :(FixArgs.@xquoteT map(x -> x, rand(10))))

    # should be `typeof(@xquote x -> isapprox(x, 1.0))`
    @test_throws Exception macroexpand(Main, :(FixArgs.@xquoteT  x -> isapprox(x, ::Float64)))
end

@testset "@xquote escaping" begin
    nested = @xquote x -> map(x, Base.OneTo(3))
    fix2 = @xquote x -> map(x, $(Base.OneTo(3)))
    @test fix2 isa FixArgs.Fix2
    @test !(nested isa FixArgs.Fix2)
    @test nested(sqrt) == fix2(sqrt)
end

@testset "@xquote calls with keyword arguments" begin
    # broken, even though `fix` is working
    @test_broken @xquote x -> isapprox(1, x; atol=3)
    @test_broken @xquote isapprox(1, 2; atol=3)
end
