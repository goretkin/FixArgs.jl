# FixArgs

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://goretkin.github.io/FixArgs.jl/dev)
[![Build Status](https://github.com/goretkin/FixArgs.jl/workflows/CI/badge.svg)](https://github.com/goretkin/FixArgs.jl/actions)
[![Coverage](https://codecov.io/gh/goretkin/FixArgs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/goretkin/FixArgs.jl)

This package aims to generalize `Base.Fix1` and `Base.Fix2` for arbitrary function arities and binding patterns with a type `Fix`.
`Fix` can also include keyword arguments.
One day, parts of this package may be included in Julia's `Base` itself; see [issue #36181](https://github.com/JuliaLang/julia/issues/36181).

Related features in other languages:
- [C++'s std::bind](https://en.cppreference.com/w/cpp/utility/functional/bind)
- [Python's functools.partial](https://docs.python.org/3/library/functools.html#functools.partial)
