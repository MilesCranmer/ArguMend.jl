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

This mechanism has (very likely) zero runtime cost, as it relies on adding splatted
keyword arguments to the function call, which will re-compile the function
if any keyword arguments change, skipping the ArguMend functions altogether.

The core function used for computing candidate keywords is `extract_close_matches`,
which is a clean-room pure-Julia re-implementation of Python's
difflib.get_close_matches.


## Example

I wrote this because [SymbolicRegression.jl](https://github.com/MilesCranmer/SymbolicRegression.jl)
has a massive number of options, and I wanted
the error to tell me or a user what parameter name was mistyped.


<details>
<summary>
The full list of options is as follows (expand):
</summary>

```julia
function Options(;
    binary_operators=[+, -, /, *],
    unary_operators=[],
    constraints=nothing,
    elementwise_loss::Union{Function,Nothing}=nothing,
    loss_function::Union{Function,Nothing}=nothing,
    tournament_selection_n::Integer=12,
    tournament_selection_p::Real=0.86,
    topn::Integer=12,
    complexity_of_operators=nothing,
    complexity_of_constants::Union{Nothing,Real}=nothing,
    complexity_of_variables::Union{Nothing,Real}=nothing,
    parsimony::Real=0.0032,
    dimensional_constraint_penalty::Union{Nothing,Real}=nothing,
    dimensionless_constants_only::Bool=false,
    alpha::Real=0.100000,
    maxsize::Integer=20,
    maxdepth::Union{Nothing,Integer}=nothing,
    turbo::Bool=false,
    bumper::Bool=false,
    migration::Bool=true,
    hof_migration::Bool=true,
    should_simplify::Union{Nothing,Bool}=nothing,
    should_optimize_constants::Bool=true,
    output_file::Union{Nothing,AbstractString}=nothing,
    node_type=nothing,
    populations::Integer=15,
    perturbation_factor::Real=0.076,
    annealing::Bool=false,
    batching::Bool=false,
    batch_size::Integer=50,
    mutation_weights=NamedTuple(),
    crossover_probability::Real=0.066,
    warmup_maxsize_by::Real=0.0,
    use_frequency::Bool=true,
    use_frequency_in_tournament::Bool=true,
    adaptive_parsimony_scaling::Real=20.0,
    population_size::Integer=33,
    ncycles_per_iteration::Integer=550,
    fraction_replaced::Real=0.00036,
    fraction_replaced_hof::Real=0.035,
    verbosity::Union{Integer,Nothing}=nothing,
    print_precision::Integer=5,
    save_to_file::Bool=true,
    probability_negate_constant::Real=0.01,
    seed=nothing,
    bin_constraints=nothing,
    una_constraints=nothing,
    progress::Union{Bool,Nothing}=nothing,
    terminal_width::Union{Nothing,Integer}=nothing,
    optimizer_algorithm::AbstractString="BFGS",
    optimizer_nrestarts::Integer=2,
    optimizer_probability::Real=0.14,
    optimizer_iterations::Union{Nothing,Integer}=nothing,
    optimizer_f_calls_limit::Union{Nothing,Integer}=nothing,
    optimizer_options=NamedTuple(),
    use_recorder::Bool=false,
    recorder_file::AbstractString="pysr_recorder.json",
    early_stop_condition::Union{Function,Real,Nothing}=nothing,
    timeout_in_seconds::Union{Nothing,Real}=nothing,
    max_evals::Union{Nothing,Integer}=nothing,
    skip_mutation_failures::Bool=true,
    nested_constraints=nothing,
    deterministic::Bool=false,
    # Not search options; just construction options:
    define_helper_functions::Bool=true,
    deprecated_return_state=nothing,
)
    return nothing
end
```

</details>

If I wrap this call with `@argumend`, I get much more useful error messages:

```julia
julia> Options(; npopulations=3)
ERROR: SuggestiveMethodError: in call to `Options`, found unsupported keyword argument:
      `npopulations`, perhaps you meant `populations` or `population_size`
```

rather than the standard Julia output:

```julia
ERROR: MethodError: no method matching Options(; npopulations::Int64)

Closest candidates are:
  Options(; binary_operators, unary_operators, constraints, elementwise_loss, loss_function, tournament_selection_n, tournament_selection_p, topn, complexity_of_operators, complexity_of_constants, complexity_of_variables, parsimony, dimensional_constraint_penalty, dimensionless_constants_only, alpha, maxsize, maxdepth, turbo, bumper, migration, hof_migration, should_simplify, should_optimize_constants, output_file, node_type, populations, perturbation_factor, annealing, batching, batch_size, mutation_weights, crossover_probability, warmup_maxsize_by, use_frequency, use_frequency_in_tournament, adaptive_parsimony_scaling, population_size, ncycles_per_iteration, fraction_replaced, fraction_replaced_hof, verbosity, print_precision, save_to_file, probability_negate_constant, seed, bin_constraints, una_constraints, progress, terminal_width, optimizer_algorithm, optimizer_nrestarts, optimizer_probability, optimizer_iterations, optimizer_f_calls_limit, optimizer_options, use_recorder, recorder_file, early_stop_condition, timeout_in_seconds, max_evals, skip_mutation_failures, nested_constraints, deterministic, define_helper_functions, deprecated_return_state) got unsupported keyword argument "npopulations"
```