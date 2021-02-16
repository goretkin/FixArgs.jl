var documenterSearchIndex = {"docs":
[{"location":"#FixArgs.jl","page":"Home","title":"FixArgs.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Depth = 3","category":"page"},{"location":"#Introduction","page":"Home","title":"Introduction","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This package began as an exploration in generalizing Base.Fix1 and Base.Fix2. These types are ways to represent a particular forms of anonymous functions. Let's illustrate. We'll use the string function in Base, which concatenates the string representations of its arguments:","category":"page"},{"location":"","page":"Home","title":"Home","text":"string(\"first \", \"second\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"Now, to construct and use the Fix1 and Fix2 types:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Base: Fix1, Fix2\n\nf1 = Fix1(string, \"one then \")\nf1(\"two\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"The function-call behavior of Fix1(f, bind) is the same as x -> f(bind, x).","category":"page"},{"location":"","page":"Home","title":"Home","text":"Similarly,","category":"page"},{"location":"","page":"Home","title":"Home","text":"f2 = Fix2(string, \" before two\")\nf2(\"one\")","category":"page"},{"location":"","page":"Home","title":"Home","text":"The function-call behavior of Fix2(f, bind) is the same as x -> f(x, bind).","category":"page"},{"location":"","page":"Home","title":"Home","text":"The key point of the Fix1 and Fix2 types is that methods can dispatch on","category":"page"},{"location":"","page":"Home","title":"Home","text":"the type of f\nthe type of bind\nthe position of bind within the function call","category":"page"},{"location":"","page":"Home","title":"Home","text":"Dispatch is not tenable with anonymous functions. Let's illustrate while moving to a more practical example using == instead of string.","category":"page"},{"location":"","page":"Home","title":"Home","text":"f1 = x -> x == 0\nf2 = Fix1(==, 0)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Now define the \"same\" things again:","category":"page"},{"location":"","page":"Home","title":"Home","text":"f3 = x -> x == 0\nf4 = Fix1(==, 0)","category":"page"},{"location":"","page":"Home","title":"Home","text":"The types of both the Fix1 values is the same:","category":"page"},{"location":"","page":"Home","title":"Home","text":"typeof(f2) === typeof(f4)","category":"page"},{"location":"","page":"Home","title":"Home","text":"But each anonymous function definition introduces a new type with an opaque name:","category":"page"},{"location":"","page":"Home","title":"Home","text":"typeof(f1), typeof(f3)","category":"page"},{"location":"","page":"Home","title":"Home","text":"A new anonymous function is always given a unique type, which allows methods to specialize on the specific anonymous function passed as an argument, but does not \"permit\" dispatch. To be more accurate, as far as dispatch is concerned, the type of anonymous functions is not special:","category":"page"},{"location":"","page":"Home","title":"Home","text":"foo(::typeof(f1)) = \"f1\"\nfoo(::typeof(f3)) = \"f3\"\nfoo(f1)\nfoo(f3)","category":"page"},{"location":"","page":"Home","title":"Home","text":"But really we'd like to use a type that is less opaque and furthermore is \"structural\" in some ways, rather than purely \"nominal\".","category":"page"},{"location":"#Examples-of-Base.Fix2","page":"Home","title":"Examples of Base.Fix2","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Where is it useful to dispatch on these special functions? Because Base does not export and does not document these types, there aren't methods in the Julia ecosystem.","category":"page"},{"location":"","page":"Home","title":"Home","text":"But these types are constructed with, for example, ==(3) or in([1, 2, 3]). A type like these is useful as a predicate to pass to higher-order functions, e.g. findfirst(==(3), some_array) to find the first element that equals 3. Brevity asside, these types are useful to define more efficient methods of generic higher-order functions. For example, take a specific method of the findfirst function:","category":"page"},{"location":"","page":"Home","title":"Home","text":"findfirst(p::Union{Fix2{typeof(isequal),Int},Fix2{typeof(==),Int}}, r::OneTo{Int}) =\n    1 <= p.x <= r.stop ? p.x : nothing","category":"page"},{"location":"","page":"Home","title":"Home","text":"The fallback for findfirst (triggered by e.g. findfirst(x->x==3, 1:10) instead of findfirst(==(3), 1:10)) would produce the same (correct) answer, but the method above will be quicker.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Dispatching on the structure of the predicate function enables a certain form of symbolic computation.","category":"page"},{"location":"#Symbolic-computation-and-lazy-evaluation","page":"Home","title":"Symbolic computation and lazy evaluation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This package provides a generalization of Fix1 and Fix2 in a few ways:","category":"page"},{"location":"","page":"Home","title":"Home","text":"A function of any positional arity can be used, and any number of its arguments can be bound, allowing the remaining arguments to be provided later.\nA function can have its keyword arguments bound.\nThe function x -> f(x, b) is represented with types:\na Lambda to represent function (args -> body)\na Call to represent the function call (f(...)) in the body\na ArgPos to represent the x in the body of the lambda function","category":"page"},{"location":"","page":"Home","title":"Home","text":"The third generalization is powerful, because it's effectively the lambda calculus.","category":"page"},{"location":"","page":"Home","title":"Home","text":"It is worth considering first just Call, which can serve the purpose of representing a delayed function call evaluation. If you prefer, you may also consider a thunk () -> foo(1, 2), which would be a Lambda (with no arguments) and a Call that does not mention any \"free variables\".","category":"page"},{"location":"","page":"Home","title":"Home","text":"If laziness is all that is needed, then defining a Julia anonymous function will do the job. But this package allows an additional benefit since methods can dispatch on details of the lazy call.","category":"page"},{"location":"","page":"Home","title":"Home","text":"In many domains, new types are introduced to represent this pattern.","category":"page"},{"location":"#Base.Iterators","page":"Home","title":"Base.Iterators","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Base.Generator consists of two fields f and iter. This can be taken as a representation of map(f, iter):","category":"page"},{"location":"","page":"Home","title":"Home","text":"using FixArgs\n\ngen = let f = string, iter = 1:10\n    @xquote map(f, iter)\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"It's certainly less nice to look at than Base.Generator{UnitRange{Int64}, typeof(string)}(string, 1:10). Better UX / ergonomics are be possible by defining a type alias:","category":"page"},{"location":"","page":"Home","title":"Home","text":"const MyGenerator{F, I} = FixArgs.Call{Some{typeof(map)}, FixArgs.FrankenTuples.FrankenTuple{Tuple{Some{F}, Some{I}, (), Tuple{}}}","category":"page"},{"location":"","page":"Home","title":"Home","text":"That is quite unsightly, and there are quite a few internals leaking out. We can use a macro instead:","category":"page"},{"location":"","page":"Home","title":"Home","text":"const MyGenerator{F, I} = @xquoteT map(::F, ::I)","category":"page"},{"location":"","page":"Home","title":"Home","text":"It should be made convenient to defining constructors and show methods that correspond with the type alias.","category":"page"},{"location":"","page":"Home","title":"Home","text":"To evaluate the call (i.e. \"collect the iterator\"):","category":"page"},{"location":"","page":"Home","title":"Home","text":"xeval(gen)","category":"page"},{"location":"","page":"Home","title":"Home","text":"This example is actually circular. The evaluation of the map call is done in terms of Generator! The definition:","category":"page"},{"location":"","page":"Home","title":"Home","text":"map(f, A) = collect(Generator(f,A))","category":"page"},{"location":"","page":"Home","title":"Home","text":"Breaking this circularity is possible by defining","category":"page"},{"location":"","page":"Home","title":"Home","text":"function iterate(gen::(@xquoteT map(::F, ::I))) where F, I\n    f = FixArgs.xeval(gen.args[1])  # not the prettiest thing right now...\n    iter = FixArgs.xeval(gen.args[2])\n    # ...\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"and might also require a separation of the purposes of collect and map. See this issue.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Many types in Base.Iterators can be seen as lazy calls of existing functions. Base.Iterators.Filter(flt, itr) could be replaced with @xquote filter(flt, itr). And the dispatches done on these types to enable the existing symbolic computation, e.g.:","category":"page"},{"location":"","page":"Home","title":"Home","text":"reverse(f::Filter) = Filter(f.flt, reverse(f.itr))","category":"page"},{"location":"","page":"Home","title":"Home","text":"Base.Iterators.Flatten, which defines a convenience function","category":"page"},{"location":"","page":"Home","title":"Home","text":"flatten(itr) = Flatten(itr)","category":"page"},{"location":"","page":"Home","title":"Home","text":"could be written in terms of a function flatten with no methods. However, it is perhaps better seen as @xquote reduce(vcat, it)","category":"page"},{"location":"#Base.Rational","page":"Home","title":"Base.Rational","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"What is Rational but lazy division on integers?","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> 1/9 * 3/2 # eager division\n0.16666666666666666","category":"page"},{"location":"","page":"Home","title":"Home","text":"using FixArgs\n\n(@xquote 1/9) * (@xquote 3/2)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Of course, we have to do some more work.","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Base: divgcd\n\nfunction Base.:*(\n        x::(@xquoteT ::T / ::T),\n        y::(@xquoteT ::T / ::T),\n        ) where {T}\n    xn, yd = divgcd(something(x.args[1]), something(y.args[2]))\n    xd, yn = divgcd(something(x.args[2]), something(y.args[1]))\n    ret = @xquote $(xn * yn) / $(xd * yd) # TODO use `unsafe_rational` and `checked_mul`\n    ret\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"Now, try again:","category":"page"},{"location":"","page":"Home","title":"Home","text":"q = (@xquote 1/9) * (@xquote 3/2)\nmap(xeval, q.args) # make numerator and denominator plainly visible","category":"page"},{"location":"","page":"Home","title":"Home","text":"compare with using // to construct a Base.Rational:","category":"page"},{"location":"","page":"Home","title":"Home","text":"1//9 * 3//2","category":"page"},{"location":"","page":"Home","title":"Home","text":"Finally, because we have encoded the relationship between this \"new\" rational type, and /, we can do:","category":"page"},{"location":"","page":"Home","title":"Home","text":"xeval(q)","category":"page"},{"location":"","page":"Home","title":"Home","text":"We could define an alias:","category":"page"},{"location":"","page":"Home","title":"Home","text":"const MyRational{T} = @xquoteT(::T / ::T)","category":"page"},{"location":"","page":"Home","title":"Home","text":"which would also enforce the same type for both the numerator and denominator, as is the case of Base.Rational.","category":"page"},{"location":"","page":"Home","title":"Home","text":"sizeof(MyRational{Int32})","category":"page"},{"location":"","page":"Home","title":"Home","text":"Occasionally, a user might find this to be a limitation, yet they would still like to use some of the generic algorithms that might apply.","category":"page"},{"location":"","page":"Home","title":"Home","text":"The fields of Base.Rational are num and den. They have to be named since that's all that gives the fields any meaning at all. In our type, however, instead of naming the fields they can be distinguished by the role they play with respect to the / function.","category":"page"},{"location":"#Fixed-Point-Numbers-and-\"static\"-arguments","page":"Home","title":"Fixed-Point Numbers and \"static\" arguments","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"A fixed-point number is just a rational number with a specified denominator. If we have a large array of fixed-point numbers with the same denominator, we certainly do not want to store the denominator repeatedly.","category":"page"},{"location":"","page":"Home","title":"Home","text":"And we want to ensure constant propagation happens, too.","category":"page"},{"location":"","page":"Home","title":"Home","text":"So we can \"bake in\" some values (Base.isbitstype) into the type of Call itself!","category":"page"},{"location":"","page":"Home","title":"Home","text":"In other words, what is a fixed-point number but lazy division with a static denominator? Here is an example that models Fixed{Int8,7} from FixedPointNumbers.jl. The macros use the notation V::::S to mark an argument V as \"static\". Also note the use of $ to escape subexpressions.","category":"page"},{"location":"","page":"Home","title":"Home","text":"using FixArgs\n\nMyQ0f7(x) = (@xquote $(Int8(x)) / 128::::S)     # hide\nMyFixed{N,D} = @xquoteT ::N / D::::S              # hide\nMyFixed{Int8, 128} === typeof(MyQ0f7(3))\n\nfunction Base.:+(a::MyFixed{N,D}, b::MyFixed{N,D})::MyFixed{N,D} where {N, D}\n    n = something(a.args[1]) + something(b.args[1])\n    return (@xquote $(N(n)) / D::::S)\nend\n\nxeval(MyQ0f7(3) + MyQ0f7(2)) === 5/128","category":"page"},{"location":"","page":"Home","title":"Home","text":"sizeof(MyFixed)\nsizeof(Int8)","category":"page"},{"location":"","page":"Home","title":"Home","text":"And the generated code appears to be equivalent between","category":"page"},{"location":"","page":"Home","title":"Home","text":"using FixedPointNumbers\nlook_inside_1(x, y) = reinterpret(Fixed{Int8, 7}, Int8(x)) + reinterpret(Fixed{Int8, 7}, Int8(y))","category":"page"},{"location":"","page":"Home","title":"Home","text":"and","category":"page"},{"location":"","page":"Home","title":"Home","text":"look_inside_2(x, y) = MyQ0f7(x) + MyQ0f7(y)","category":"page"},{"location":"#Pure-imaginary-type-and-Base.Complex","page":"Home","title":"Pure-imaginary type and Base.Complex","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Now that we can make some arguments static, we can introduce a meaningful example where the lazy call might not be valid to begin with. You can define a type such that xeval raises MethodError and still represent the computation symbolically. The Julia ecosystem goes to great lengths to find the right generic functions and to ensure that all methods defined on generic functions are semantically compatible. This effort enables generic programming and interoperability. You can define a type A in terms of a function f and a type B even if it may not make sense to define a new method of f on B.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Here is an over-the-top example:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using FixArgs\n\nstruct ImaginaryUnit end    # if we want to be really cute, can do `@xquote sqrt((-1)::::S)`\nconst Imaginary{T} = @xquoteT ::T * ::ImaginaryUnit\nImaginary(x) = @xquote x * $(ImaginaryUnit())   # note escaping","category":"page"},{"location":"","page":"Home","title":"Home","text":"note that if we assume we have no Base.Complex or anything like it, we don't have a way to further evaluate:","category":"page"},{"location":"","page":"Home","title":"Home","text":"xeval(Imaginary(3))","category":"page"},{"location":"","page":"Home","title":"Home","text":"We represented pure imaginary numbers as lazy multiplication of numbers and a singleton type ImaginaryUnit, and it is basically as if we had defined","category":"page"},{"location":"","page":"Home","title":"Home","text":"struct Imaginary{T}\n    _::T\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"Let's just go ahead and represent complex numbers too:","category":"page"},{"location":"","page":"Home","title":"Home","text":"# const MyComplex{R, I} = @xquoteT ::R + (::I * ::ImaginaryUnit) # TODO this macro doesn't work\nMyComplex(r, i) = @xquote r + i * $(ImaginaryUnit())","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note this monster of a type has the same size as Base.Complex:","category":"page"},{"location":"","page":"Home","title":"Home","text":"sizeof(Complex(1, 2))\nsizeof(MyComplex(1, 2))","category":"page"},{"location":"","page":"Home","title":"Home","text":"and layout too:","category":"page"},{"location":"","page":"Home","title":"Home","text":"reinterpret(Int64, [Complex(1, 2)])\nreinterpret(Int64, [MyComplex(1, 2)])","category":"page"},{"location":"","page":"Home","title":"Home","text":"Of course, there are many different types that would all be mathematically equivalent by swapping the arguments to + or *. Note that swapping the arguments to + would give a different memory layout.","category":"page"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = FixArgs\nDocTestSetup = quote\n    using FixArgs\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [FixArgs]","category":"page"},{"location":"#FixArgs.ArgPos","page":"Home","title":"FixArgs.ArgPos","text":"Within the body of a Lambda, represent a formal positional parameter of thatLambda.\n\n\n\n\n\n","category":"type"},{"location":"#FixArgs.Arity","page":"Home","title":"FixArgs.Arity","text":"Represent the arity of a Lambda.\n\nCurrently, only represents a fixed number of positional arguments, but may be generalized to include optional and keyword arguments.\n\nP is 0, 1, 2, ... KW is always NoKeywordArguments, and may be extended in the future.\n\n\n\n\n\n","category":"type"},{"location":"#FixArgs.Call","page":"Home","title":"FixArgs.Call","text":"A call \"f(args...)\". args may represent both positional and keyword arguments.\n\n\n\n\n\n","category":"type"},{"location":"#FixArgs.Context","page":"Home","title":"FixArgs.Context","text":"terms are evaluated with respect to a Context A Context is an associations between bound variables and values, and they may be nested (via the parent field).\n\n\n\n\n\n","category":"type"},{"location":"#FixArgs.Lambda","page":"Home","title":"FixArgs.Lambda","text":"A lambda expression \"args -> body\"\n\n\n\n\n\n","category":"type"},{"location":"#FixArgs.ParentScope","page":"Home","title":"FixArgs.ParentScope","text":"Nest ArgPos in ParentScopes to represent a reference to the formal parameters of a \"parent\" function. Forms a unary representation.\n\nRelated: [De Bruijn indices]https://en.wikipedia.org/wiki/DeBruijnindex\n\n\n\n\n\n","category":"type"},{"location":"#FixArgs.TypedExpr","page":"Home","title":"FixArgs.TypedExpr","text":"Roughly mirror Base.Expr, except that the the head of the expression (encoded in the head field) can be dispatched on.\n\nThis is only used in an intermediate representation of this package.\n\nNote that Expr and TypedExpr are constructed slightly differently. Each argument of an Expr is an argument to Expr, whereas all arguments of a TypedExpr are passed as one argument (a tuple) to TypedExpr\n\ne.g.\n\nExpr(:call, +, 1, 2) corresponds to TypedExpr(Val{:call}(), (+, 1, 2))\n\n\n\n\n\n","category":"type"},{"location":"#FixArgs.isexpr-Tuple{Expr}","page":"Home","title":"FixArgs.isexpr","text":"isexpr(expr) -> Bool\nisexpr(expr, head) -> Bool\n\nChecks whether given value isa Base.Expr and if further given head, it also checks whether the head matches expr.head.\n\nExamples\n\njulia> using ExprParsers\njulia> EP.isexpr(:(a = hi))\ntrue\njulia> EP.isexpr(12)\nfalse\njulia> EP.isexpr(:(f(a) = a), :(=))\ntrue\njulia> EP.isexpr(:(f(a) = a), :function)\nfalse\n\n\n\n\n\n","category":"method"},{"location":"#FixArgs.lc_expr-Tuple{Any}","page":"Home","title":"FixArgs.lc_expr","text":"Convert a ::TypedExpr to a Lambda-Call expression\n\n\n\n\n\n","category":"method"},{"location":"#FixArgs.normalize_lambda_1_arg-Tuple{Any}","page":"Home","title":"FixArgs.normalize_lambda_1_arg","text":"normalize :(x -> body) into  :((x,) -> body)\n\n\n\n\n\n","category":"method"},{"location":"#FixArgs.postwalk-Tuple{Any,Any}","page":"Home","title":"FixArgs.postwalk","text":"postwalk(f, expr)\n\nApplies f to each node in the given expression tree, returning the result. f sees expressions after they have been transformed by the walk.\n\nSee also: prewalk.\n\n\n\n\n\n","category":"method"},{"location":"#FixArgs.prewalk-Tuple{Any,Any,Any}","page":"Home","title":"FixArgs.prewalk","text":"prewalk(f, expr)\n\nApplies f to each node in the given expression tree, returning the result. f sees expressions before they have been transformed by the walk, and the walk will be applied to whatever f returns.\n\nThis makes prewalk somewhat prone to infinite loops; you probably want to try postwalk first.\n\n\n\n\n\n","category":"method"},{"location":"#FixArgs.relabel_args","page":"Home","title":"FixArgs.relabel_args","text":"α-conversion in λ-calculus\n\nlabeler(x) produces a Symbol or similar from x.referent_depth x.antecedent_depth x.arg_i x.sym – name before relabeling\n\nx.referent_depth - x.antecedent_depth is number of ->s that are between the evaluation site and the definition site\n\n\n\n\n\n","category":"function"},{"location":"#FixArgs.uneval-Tuple{Expr}","page":"Home","title":"FixArgs.uneval","text":"Given a value, produce an expression that when eval'd produces the value.\n\ne.g.\n\njulia> eval(uneval(Expr(:my_call, :arg1, :arg2)))\n:($(Expr(:my_call, :arg1, :arg2)))\n\njulia> eval(eval(uneval(:(sqrt(9)))))\n3.0\n\nThis function is used to return expressions from this package's macros. This is likely not a well-posed problem to begin with. Related issue.\n\nNote the special case for :(esc(x)).\n\n\n\n\n\n","category":"method"},{"location":"#FixArgs.xapply","page":"Home","title":"FixArgs.xapply","text":"apply a Lambda expression to arguments.\n\n\n\n\n\n","category":"function"},{"location":"#FixArgs.xeval-Tuple{FixArgs.Call}","page":"Home","title":"FixArgs.xeval","text":"evaluate a Lambda-Call expression\n\nCurrently only works on Call expressions.\n\n\n\n\n\n","category":"method"},{"location":"#FixArgs.@fix-Tuple{Any}","page":"Home","title":"FixArgs.@fix","text":"A convenience macro that implements the syntax of this PR\n\n@fix f(_, b) is the equivalent of x -> f(x, b)\n\n\n\n\n\n","category":"macro"},{"location":"#FixArgs.@quote_some-Tuple{Any}","page":"Home","title":"FixArgs.@quote_some","text":"This macro is used to debug and introspect the escaping behavior of @xquote\n\njulia> dump(let x = 9\n       @xquote sqrt(x)\n       end)\nExpr\n    head: Symbol call\n    args: Array{Any}((2,))\n        1: sqrt (function of type typeof(sqrt))\n        2: Int64 9\n\n\n\n\n\n","category":"macro"},{"location":"#FixArgs.@xquote-Tuple{Any}","page":"Home","title":"FixArgs.@xquote","text":"Transform julia syntax into a Lambda-Call expression.\n\n\n\n\n\n","category":"macro"},{"location":"#FixArgs.@xquoteT-Tuple{Any}","page":"Home","title":"FixArgs.@xquoteT","text":"The types produced by this package are unwieldly. This macro permits a convenient syntax, e.g. @xquoteT func(::Arg1Type, ::Arg2Type) to represent types.\n\nlet func = identity, arg = 1\n    typeof(@xquote func(arg)) == @xquoteT func(::typeof(arg))\nend\n\n# output\n\ntrue\n\nIf an argument is \"static\", then it is part of the type, and the value is annotated as illustrated:\n\njulia> @xquoteT string(123::::S)\nFixArgs.Call{Some{typeof(string)},FrankenTuples.FrankenTuple{Tuple{Val{123}},(),Tuple{}}}\n\n\n\n\n\n","category":"macro"}]
}
