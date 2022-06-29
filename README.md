# FixArgs

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://goretkin.github.io/FixArgs.jl/dev)
[![Build Status](https://github.com/goretkin/FixArgs.jl/workflows/CI/badge.svg)](https://github.com/goretkin/FixArgs.jl/actions)
[![Coverage](https://codecov.io/gh/goretkin/FixArgs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/goretkin/FixArgs.jl)

This package aims to generalize `Base.Fix1` and `Base.Fix2` for arbitrary function arities and binding patterns with a type `Fix`.
`Fix` can also include keyword arguments.
One day, parts of this package may be included in Julia's `Base` itself; see [issue #36181](https://github.com/JuliaLang/julia/issues/36181).

See the documentation for more detail and examples.

Related features in other languages:
- [C++'s std::bind](https://en.cppreference.com/w/cpp/utility/functional/bind)
- [Python's functools.partial](https://docs.python.org/3/library/functools.html#functools.partial)

## Video
A lightning talk about this package was presented at JuliaCon 2021.

[![JuliaCon 2021 talk recording](https://img.youtube.com/vi/9GseaBzoNj8/0.jpg)](https://www.youtube.com/watch?v=9GseaBzoNj8)

## Development

### Julia line coverage information in VS Code

First generate `.cov` files:
```julia
using Pkg
Pkg.test("FixArgs"; coverage=true)
```

Then
```julia
using Coverage
coverage = process_folder()
open("lcov.info", "w") do io
    LCOV.write(io, coverage)
end;
```

Finally, Open a source file in VS Code and run the command "Coverage Gutters: Display Coverage" in the VS Code Command Pallet.
