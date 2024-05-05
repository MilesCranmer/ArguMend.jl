<div align="center">

# ArguMend.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://astroautomata.com/ArguMend.jl/dev/)
[![Build Status](https://github.com/MilesCranmer/ArguMend.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/MilesCranmer/ArguMend.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://coveralls.io/repos/github/MilesCranmer/ArguMend.jl/badge.svg?branch=main)](https://coveralls.io/github/MilesCranmer/ArguMend.jl?branch=main)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

</div>
  
ArguMend.jl lets you automatically suggest
similarly-spelled keywords.

```julia
@argumend function f(; kw)
    kw + 1
end
```

this will fill in some logic that will result in a nicer
mechanism for invalid keywords:

```julia
julia> f(kwww=2)
```
