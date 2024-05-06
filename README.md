<div align="center">

# ArguMend.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroautomata.com/ArguMend.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/ArguMend.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/MilesCranmer/ArguMend.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/ArguMend.jl/badge.svg?branch=master)](https://coveralls.io/github/MilesCranmer/ArguMend.jl?branch=master)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

</div>
  
ArguMend.jl injects a function with logic
to help with mistyped keyword arguments.

```julia
@argumend function f(a, b; niterations=10, kw2=2)
    a + b - niterations + kw2
end
```

This results in a nicer mechanism for MethodErrors:

```julia
julia> f(1, 2; iterations=1)
ERROR: SuggestiveMethodError: in call to `f`, found unsupported
       keyword argument: `iterations`, perhaps you meant `niterations`
```

This becomes increasingly useful when calling into a
large interface with many possible options.

This mechanism has zero runtime cost, as it relies on adding splatted
keyword arguments to the function call, which will re-compile the function
if any keyword arguments change, skipping the ArguMend functions altogether.

The core function used for computing candidate keywords is `extract_close_matches`,
which is a clean-room pure-Julia re-implementation of Python's
difflib.get_close_matches.