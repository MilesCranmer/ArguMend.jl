<div align="center">

# ArguMend.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroautomata.com/ArguMend.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/ArguMend.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/MilesCranmer/ArguMend.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/ArguMend.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/ArguMend.jl?branch=master)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

</div>
  
ArguMend.jl lets you automatically suggest similarly-spelled keywords.

```julia
@argumend function f(a, b; niterations=10)
    a + b - niterations
end
```

This results in a nicer mechanism for mistyped API calls:

```julia
julia> f(1, 2; iterations=1, abc=2)
ERROR: SuggestiveMethodError: in call to `f`, found unsupported
       keyword argument: `iterations`, perhaps you meant `niterations`
```

This is most useful for large interfaces with many possible options.

This mechanism is (probably) zero-cost, as it relies on adding splatted
keyword arguments to the function call, which will re-compile the function
if the keyword arguments change.

The core function used for computing candidate keywords is `extract_close_matches`,
which is a clean-room pure-Julia re-implementation of Python's
difflib.get_close_matches.
