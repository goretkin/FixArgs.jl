var documenterSearchIndex = {"docs":
[{"location":"#Curry.jl-1","page":"Home","title":"Curry.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"Documentation for Curry.jl","category":"page"},{"location":"#","page":"Home","title":"Home","text":"CurrentModule = Curry\nDocTestSetup = quote\n    using Curry\nend","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Modules = [Curry]\nOrder   = [:function, :type]","category":"page"},{"location":"#Curry.Bind","page":"Home","title":"Curry.Bind","text":"Represent a function call, with partially bound arguments.\n\nb = Bind(+, (1, 2))\nb()\n\n# output\n\n3\n\nb = Bind(*, (\"hello\", nothing))\nb(\", world\")\n\n# output\n\n\"hello, world\"\n\nBind(f, (g(), h())) is like :(f(g(), h())) but f g and h are lexically scoped, and g() and h() are evaluated eagerly.\n\n\n\n\n\n","category":"type"},{"location":"#Curry.interleave-Tuple{Any,Any}","page":"Home","title":"Curry.interleave","text":"Return a Tuple that interleaves args into the nothing slots of slots.\n\nCurry.interleave((:a, nothing, :c, nothing), (12, 34))\n\n# output\n\n(:a, 12, :c, 34)\n\nUse Some to escape nothing\n\nCurry.interleave((:a, Some(nothing), :c, nothing), (34,))\n\n# output\n\n(:a, nothing, :c, 34)\n\n\n\n\n\n","category":"method"}]
}
