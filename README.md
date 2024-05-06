<div align="center">

# ArguMend.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroautomata.com/ArguMend.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/ArguMend.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/MilesCranmer/ArguMend.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/ArguMend.jl/badge.svg?branch=main)](https://coveralls.io/github/MilesCranmer/ArguMend.jl?branch=main)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

</div>
  
ArguMend.jl lets you automatically suggest
similarly-spelled keywords:

```julia
@argumend function f(a, b; niterations=10)
    a + b - niterations
end
```

which results in a nicer mechanism for invalid keywords:

```julia
julia> f(1, 2; iterations=1)
ERROR: SuggestiveMethodError: in call to `f`, found unsupported keyword argument: `iterations`, perhaps you meant `niterations`

Stacktrace:
 [1] f(a::Int64, b::Int64; niterations::Int64, invalid_kws#231::@Kwargs{iterations::Int64})
   @ Main ~/PermaDocuments/ArguMend.jl/src/ArguMend.jl:69
 [2] top-level scope
   @ REPL[14]:1
```

This is most useful for large interfaces with many possible options.

This mechanism is very likely zero-cost, as it relies on adding splatted
keyword arguments to the function call, which will re-compile the function
if the keyword arguments change.
