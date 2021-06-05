### A Pluto.jl notebook ###
# v0.14.7

using Markdown
using InteractiveUtils

# ╔═╡ c1104bdc-c5a3-11eb-177b-8f0481537ff2
using BenchmarkTools

# ╔═╡ 76b03797-f61f-4f4b-ba3c-747454701b5f
using FixArgs

# ╔═╡ df43e182-4c66-43b8-a993-76471bcd924d
md"""
Suppose we have a `Vector` of `Vector`s, and we want to concatenate all of the inner `Vector`s into one `Vector`.
"""

# ╔═╡ 74e88dbb-2ad5-4c79-a50a-80cc931397bd
vs = [1:100 for _ = 1:200]; # `Vector` of `<:AbstractVector`,  really.

# ╔═╡ f9ae9e87-601a-4b08-b1f1-fe3b80f7de99
md"""
To concatenate two `AbstractVector`s, use `vcat`:
"""

# ╔═╡ 13863016-97c5-45fd-944a-3d2202150f91
vcat(1:5, 1:5)

# ╔═╡ 5c6c0dc5-e14c-4893-aee0-fe7311318c7d
md"""
Apply binary operation over a sequence using `reduce`:
"""

# ╔═╡ 983987e0-1c29-4889-af87-f3c351eeb693
reduce(vcat, vs)

# ╔═╡ b52db293-ccbb-4816-b541-31968f9bca62
md"""
Let's time it:
"""

# ╔═╡ cd898a79-5f18-4037-9d9c-4018340f8f41
@benchmark reduce(vcat, vs)

# ╔═╡ 42ae54e7-fdb8-4874-af81-02607860fcf1
md"""
Now let us do essentially the same computation, but instead of directly using `vcat`, we define a function (an anonymous function) that is just a wrapper around `vcat`.
"""

# ╔═╡ 20859a05-dcc4-43d1-88d9-cdf01d73978c
@benchmark reduce((_1, _2) -> vcat(_1, _2), vs)

# ╔═╡ 47ccbb70-e6e0-46f5-87cf-5c2eda9dfcfb
md"""
It is ~100× slower in this case.
It is not because anonymous functions are slow.
"""

# ╔═╡ ec98ff2d-d6cf-499c-bc1d-fa1c9fbf6b12
methods(reduce)

# ╔═╡ 2d3c5552-3dd1-4061-9313-5fb8525a290b
md"""
Multiple dispatch and each-function-is-a-type allow us to use a special case that allocates the result all at once, with the spelling `reduce(vcat, ...)`. Without these features, one would instead need to make a new name like e.g. `reduce_vcat(...)`.

Personally, the first spelling is better because it combines existing and meaningful names instead of introducing a new ad-hoc name.

Note that `reduce(vcat, ...)` might not even call `vcat`, but that `vcat` is used as a _name_. More so than in other ecosystems, Julia tries to pin down the meaning of function names to enable generic programming.
"""

# ╔═╡ 0208ca74-6a4b-4a26-a45c-4ee45078fa18
md"""
There are multiple converging motivations for the idea in this talk:
* Get extra value from careful function name / meaning pairs
* Generalize `Base.Fix1`/`Base.Fix2`
* Symbolic Computation / Lazy Computation
* structural vs nominal
"""

# ╔═╡ ecfd6ed7-10d2-411a-ae24-2d404d677894
f1 = ==(50)

# ╔═╡ 6a907b67-a758-4111-ae74-6d65b58ac8a1
f2 = x -> x == 50

# ╔═╡ 9edfe7bc-aab6-49b6-b008-ab1a1aab2dba
md"""
`f1` and `f2` compute the same function. Some might say that they are different names for the name function.

And in this case, names matter!
"""

# ╔═╡ 8b84afa0-5e8e-447e-aebf-e726fab49c8e
findfirst(f1, 1:100)

# ╔═╡ 87400aee-36f2-4053-a78a-363c6bec331d
findfirst(f2, 1:100)

# ╔═╡ d3e5ec14-eb83-4210-a2ba-f3a56c567421
@which findfirst(f1, 1:100)

# ╔═╡ 3e293d32-a655-44ba-803b-814d159a2cb4
md"""
```julia
findfirst(p::Union{Fix2{typeof(isequal),T},Fix2{typeof(==),T}}, r::AbstractUnitRange) where {T<:Integer} =
    first(r) <= p.x <= last(r) ? 1+Int(p.x - first(r)) : nothing
```
"""

# ╔═╡ 5982b56b-2b3f-46f4-b3b9-1ee50f8a7f19
md"""
This kind of thing is why I love Julia. Imagine for example a plotting library that supports unevenly spaced axis ticks.
If you write some code in terms of `findfirst`, then it can support unevenly spaced ticks, and still be (runtime) efficient when using evenly spaced ticks.
"""

# ╔═╡ 564136f7-d061-420e-8047-899f90f9f686
md"""
`Fix1`/`Fix2` fix one argument of a two-argument function.

Would it ever be useful to fix all of the arguments of a function?
"""

# ╔═╡ 44997615-606a-4561-a2f9-3ce6b0541b2e
md"""
Consier the `/` function.
If you fix its two arguments, that's pretty much `Rational`.
"""

# ╔═╡ 81a8a996-3cfb-4ace-a4f3-75e94d5e1c4d
half = @xquote 1 / 2

# ╔═╡ aa3e5cae-8467-455d-97b6-67a49637a53f
function Base.:*(a::(@xquoteT ::S / ::S), b::(@xquoteT ::S / ::S)) where S
	(n1, d1) = something.(Tuple(a.args))
	(n2, d2) = something.(Tuple(b.args))
	@show n1 d1 n2 d2
	@xquote $(n1 * n2) / $(d1 * d2)
end
	

# ╔═╡ 6ea7a502-0ed9-42a7-a0d9-5456b86c77d8
half * half

# ╔═╡ 23060b91-fd0d-4dd1-b202-7811d255315f


# ╔═╡ 320cfbe4-e757-4258-a84b-662e92c0d043


# ╔═╡ 4fab7d76-7683-4b3b-bec5-5fb0bef6e9bf


# ╔═╡ ba1de521-42f5-4b92-b109-ae8e89bdfc72


# ╔═╡ 5e77d3ff-1f6f-4d57-a7a4-0e190bec9733


# ╔═╡ 6cfab83c-f8ec-4e47-999d-9f5d5b362cf3


# ╔═╡ 8a94ea28-ecb5-4793-bdd9-3f1d3dbf7f68


# ╔═╡ 69587301-e382-4cb9-8013-012589d585aa


# ╔═╡ b2ccd533-9690-496b-842f-a6d9dcf6a301


# ╔═╡ b8a8b131-011f-4fa6-9490-cceaf959f34b


# ╔═╡ 767dbaf5-5f00-46ee-9f11-586b4f08f4a1


# ╔═╡ b8c3de50-3537-4c56-bd5f-f131787c5445
md"""
Using this instead of `Base.Rational` seems pretty silly, until you consider
* Some users want a "rational" type where the numerator and the denominator are not constrained to be the same type.
* a fixed-point number is one of these rational types where the denominator is "static" (a singleton type such that the numerical value is encoded in the type domain)
"""

# ╔═╡ 931890bf-6dc4-46c0-b2dd-8aae21b888c5


# ╔═╡ 1f9cfd78-9b86-40c8-b269-ca172891fd37


# ╔═╡ 6fc710f9-1952-4fa8-ac14-8bb4e38fe392


# ╔═╡ 1843678a-bc42-4ee0-8166-9d6edd3dc429
ft.

# ╔═╡ 98bba0af-8751-4a42-afbd-1d2ae190d559


# ╔═╡ 4982ead6-c6e4-4c8f-b28e-7ae4f3f57692


# ╔═╡ d1195b21-41fd-48ad-9eea-6479c939c54b


# ╔═╡ 82204b86-9f59-40d6-a69d-a92d712219f7


# ╔═╡ 5442cb4c-3f63-4a7c-ad54-1bd7de2eeb9b


# ╔═╡ a4191b28-2bc8-4c7f-8b69-b0ec49903622


# ╔═╡ 8e45f108-15dd-4da7-b700-3928b99c60b1


# ╔═╡ 778db0b6-0e1e-45e9-9fd5-84eb86d3b1b3


# ╔═╡ b03ba110-0d61-4123-a34b-ac277af4efa0


# ╔═╡ 893fa16e-82a9-4299-9a40-ca16f7b5a6e5


# ╔═╡ 2aa429ef-5c36-42dd-b52a-305e11b0cc14


# ╔═╡ 8002eb1a-32f5-471d-8097-56ac6d53a634


# ╔═╡ 45dca60c-0db7-470d-a722-3fd67eae8678


# ╔═╡ f143338d-0acd-45c2-a4b0-91a1cbd65f13


# ╔═╡ 33479abe-7ef7-423c-a746-a5300a9821d9


# ╔═╡ 4f0adce9-08ae-459a-a9a3-4cd20c1a7e7e


# ╔═╡ 0d790272-418a-4c24-90fc-cd03fbe1803c


# ╔═╡ 27892012-8ec6-4def-aff2-0273a5c4eb14


# ╔═╡ f90a6b06-47fa-4c2f-b88c-b410258c7e91


# ╔═╡ f076a27e-1015-4424-a07c-c06341117a31


# ╔═╡ 2b02c423-1215-49ff-84cf-aab3572dd9c7


# ╔═╡ Cell order:
# ╟─df43e182-4c66-43b8-a993-76471bcd924d
# ╠═74e88dbb-2ad5-4c79-a50a-80cc931397bd
# ╟─f9ae9e87-601a-4b08-b1f1-fe3b80f7de99
# ╠═13863016-97c5-45fd-944a-3d2202150f91
# ╟─5c6c0dc5-e14c-4893-aee0-fe7311318c7d
# ╠═983987e0-1c29-4889-af87-f3c351eeb693
# ╟─b52db293-ccbb-4816-b541-31968f9bca62
# ╠═c1104bdc-c5a3-11eb-177b-8f0481537ff2
# ╠═cd898a79-5f18-4037-9d9c-4018340f8f41
# ╟─42ae54e7-fdb8-4874-af81-02607860fcf1
# ╠═20859a05-dcc4-43d1-88d9-cdf01d73978c
# ╟─47ccbb70-e6e0-46f5-87cf-5c2eda9dfcfb
# ╠═ec98ff2d-d6cf-499c-bc1d-fa1c9fbf6b12
# ╟─2d3c5552-3dd1-4061-9313-5fb8525a290b
# ╠═0208ca74-6a4b-4a26-a45c-4ee45078fa18
# ╠═ecfd6ed7-10d2-411a-ae24-2d404d677894
# ╠═6a907b67-a758-4111-ae74-6d65b58ac8a1
# ╠═9edfe7bc-aab6-49b6-b008-ab1a1aab2dba
# ╠═8b84afa0-5e8e-447e-aebf-e726fab49c8e
# ╠═87400aee-36f2-4053-a78a-363c6bec331d
# ╠═d3e5ec14-eb83-4210-a2ba-f3a56c567421
# ╟─3e293d32-a655-44ba-803b-814d159a2cb4
# ╟─5982b56b-2b3f-46f4-b3b9-1ee50f8a7f19
# ╟─564136f7-d061-420e-8047-899f90f9f686
# ╠═44997615-606a-4561-a2f9-3ce6b0541b2e
# ╠═76b03797-f61f-4f4b-ba3c-747454701b5f
# ╠═81a8a996-3cfb-4ace-a4f3-75e94d5e1c4d
# ╠═aa3e5cae-8467-455d-97b6-67a49637a53f
# ╠═6ea7a502-0ed9-42a7-a0d9-5456b86c77d8
# ╠═23060b91-fd0d-4dd1-b202-7811d255315f
# ╠═320cfbe4-e757-4258-a84b-662e92c0d043
# ╠═4fab7d76-7683-4b3b-bec5-5fb0bef6e9bf
# ╠═ba1de521-42f5-4b92-b109-ae8e89bdfc72
# ╠═5e77d3ff-1f6f-4d57-a7a4-0e190bec9733
# ╠═6cfab83c-f8ec-4e47-999d-9f5d5b362cf3
# ╠═8a94ea28-ecb5-4793-bdd9-3f1d3dbf7f68
# ╠═69587301-e382-4cb9-8013-012589d585aa
# ╠═b2ccd533-9690-496b-842f-a6d9dcf6a301
# ╠═b8a8b131-011f-4fa6-9490-cceaf959f34b
# ╠═767dbaf5-5f00-46ee-9f11-586b4f08f4a1
# ╠═b8c3de50-3537-4c56-bd5f-f131787c5445
# ╠═931890bf-6dc4-46c0-b2dd-8aae21b888c5
# ╠═1f9cfd78-9b86-40c8-b269-ca172891fd37
# ╠═6fc710f9-1952-4fa8-ac14-8bb4e38fe392
# ╠═1843678a-bc42-4ee0-8166-9d6edd3dc429
# ╠═98bba0af-8751-4a42-afbd-1d2ae190d559
# ╠═4982ead6-c6e4-4c8f-b28e-7ae4f3f57692
# ╠═d1195b21-41fd-48ad-9eea-6479c939c54b
# ╠═82204b86-9f59-40d6-a69d-a92d712219f7
# ╠═5442cb4c-3f63-4a7c-ad54-1bd7de2eeb9b
# ╠═a4191b28-2bc8-4c7f-8b69-b0ec49903622
# ╠═8e45f108-15dd-4da7-b700-3928b99c60b1
# ╠═778db0b6-0e1e-45e9-9fd5-84eb86d3b1b3
# ╠═b03ba110-0d61-4123-a34b-ac277af4efa0
# ╠═893fa16e-82a9-4299-9a40-ca16f7b5a6e5
# ╠═2aa429ef-5c36-42dd-b52a-305e11b0cc14
# ╠═8002eb1a-32f5-471d-8097-56ac6d53a634
# ╠═45dca60c-0db7-470d-a722-3fd67eae8678
# ╠═f143338d-0acd-45c2-a4b0-91a1cbd65f13
# ╠═33479abe-7ef7-423c-a746-a5300a9821d9
# ╠═4f0adce9-08ae-459a-a9a3-4cd20c1a7e7e
# ╠═0d790272-418a-4c24-90fc-cd03fbe1803c
# ╠═27892012-8ec6-4def-aff2-0273a5c4eb14
# ╠═f90a6b06-47fa-4c2f-b88c-b410258c7e91
# ╠═f076a27e-1015-4424-a07c-c06341117a31
# ╠═2b02c423-1215-49ff-84cf-aab3572dd9c7
