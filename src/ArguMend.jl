module ArguMend

export @argumend, extract_close_matches, suggest_alternative_kws

using MacroTools: splitdef, combinedef
using TestItems: @testitem

"""
    @argumend [n_suggestions=3] [cutoff=0.6] funcdef

This macro lets you automatically suggest
similarly-spelled keywords:

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

This function computes closeness between the mistyped keyword argument
by counting the maximum number of matching subsequences with all the other
keyword arguments.

You can customize the number of suggestions by specifying it in
the macro. You can also control the closeness threshold with `cutoff`.
"""
macro argumend(args...)
    return esc(argumend(args...))
end

"""Errors coming from the construction of an ArguMend function."""
struct ArguMendMacroError <: Exception
    msg::String
end

"""MethodError but with suggestions for alternative keywords."""
struct SuggestiveMethodError <: Exception
    msg::String
    f::Any
    SuggestiveMethodError(msg, @nospecialize(f)) = new(msg, f)
end

function Base.showerror(io::IO, e::SuggestiveMethodError)
    print(io, "SuggestiveMethodError: ")
    print(io, "in call to `$(e.f)`, ")
    print(io, e.msg)
    print(io, "\n")
end

function argumend(args...)
    argumend_options, raw_fdef = args[begin:end-1], args[end]

    n_suggestions = 3
    cutoff = 0.6
    for option in argumend_options
        if option isa Expr && option.head == :(=)
            if option.args[1] == :n_suggestions
                n_suggestions = option.args[2]
                continue
            elseif option.args[1] == :cutoff
                cutoff = option.args[2]
                continue
            end
        end
        throw(ArguMendMacroError("Unknown argumend option: $option"))
    end

    fdef = splitdef(raw_fdef)
    _validate_argumend(fdef)
    name = fdef[:name]
    # args = fdef[:args]
    kwargs = fdef[:kwargs]
    body = fdef[:body]

    kwarg_strings = let
        map(kwargs) do kw
            if kw isa Symbol
                string(kw)
            elseif kw isa Expr && kw.head == :(kw)
                string(kw.args[1])
            else
                error("Unexpected format for kwarg: $kw")
                ""
            end
        end
    end
    kwarg_strings_t = Tuple(kwarg_strings)

    # tuple_args = Tuple(args)

    @gensym invalid_kws msg
    kwargs = vcat(kwargs, :($(invalid_kws)...))

    body = quote
        if !isempty($invalid_kws)
            let $msg = $(suggest_alternative_kws)(
                    keys($invalid_kws),
                    $kwarg_strings_t;
                    n_suggestions = $n_suggestions,
                    cutoff = $cutoff,
                )
                throw($(SuggestiveMethodError)($msg, $name))
            end
        end
        $body
    end

    fdef[:kwargs] = kwargs
    fdef[:body] = body

    return combinedef(fdef)
end

"""
    suggest_alternative_kws(kws, possible_kws; n_suggestions = 3, cutoff = 0.6)

Suggest alternative keywords, where `kws` is the list of keyword
names passed to a function, and `possible_kws` is the list of
true keyword names.
These should be either symbols or strings.
You can get this from the function `kws` by using `keys(kws)`.

# Examples


```julia
function f(; kws...)
    msg = suggest_alternative_kws(keys(kws), [:kw1, :kw2])
    if isempty(msg)
        return "all keywords are valid"
    else
        return "received some invalid keywords, here is the error:" * msg
    end
end
```
"""
function suggest_alternative_kws(kws, possible_kws; n_suggestions = 3, cutoff = 0.6)
    msg = String[]
    _possible_kws = string.(possible_kws)
    for k in kws
        has_exact_match = any(==(string(k)), _possible_kws)
        if has_exact_match
            continue
        end
        close_matches =
            extract_close_matches(string(k), _possible_kws; n = n_suggestions, cutoff)
        if isempty(close_matches)
            push!(
                msg,
                "found unsupported keyword argument: `$k`, without any close matches",
            )
        else
            wrapped_names = map(s -> "`$s`", close_matches)
            push!(
                msg,
                "found unsupported keyword argument: `$k`, perhaps you meant $(join(wrapped_names, " or "))",
            )
        end
    end
    num_msgs = length(msg)
    if num_msgs == 0
        return ""
    elseif num_msgs == 1
        return msg[1]
    else
        return "\n\t " * join(msg, ",\n\t and also ")
    end
end


@testitem "Basic usage" begin
    using ArguMend: @argumend, SuggestiveMethodError

    @argumend f(; kw = 1) = kw + 1

    @test_throws SuggestiveMethodError f(kww = 2)
    @test_throws SuggestiveMethodError f(b = 2)
    if VERSION >= v"1.9"
        @test_throws "perhaps you meant `kw`" f(kww = 2)
        @test_throws "without any close matches" f(b = 2)
    end

    # With more complex method
    @argumend function f(
        a,
        b,
        c;
        niterations = 1,
        ncycles_per_iteration = 1,
        niterations_per_cycle = 1,
        abcdef = 1,
        iter = 1,
    )
        return nothing
    end

    @test f(1, 2, 3) == nothing

    let g = () -> f(1, 2, 3; iterations = 2)
        @test_throws SuggestiveMethodError g()
        if VERSION >= v"1.9"
            @test_throws "in call to `f`" g()
            @test_throws "found unsupported keyword argument: `iterations`, perhaps you meant `niterations` or `niterations_per_cycle`" g()
        end
    end

    # Multiple suggestions
    let g = () -> f(1, 2, 3; iterations = 1, abc = 1, blahblahblah = 1)
        @test_throws SuggestiveMethodError g()
        if VERSION >= v"1.9"
            @test_throws "and also found unsupported keyword argument: `abc`, perhaps you meant `abcdef`" g()
            @test_throws "and also found unsupported keyword argument: `blahblahblah`, without any close matches" g()
        end
    end
end

@testitem "Manual calling" begin
    using ArguMend
    function f(; kws...)
        msg = suggest_alternative_kws(keys(kws), [:kw1, :kw2])
        if isempty(msg)
            return 1
        else
            return msg
        end
    end
    @test f(; kw1 = 1) == 1
    @test f(; kw1 = 1, kw2 = 2) == 1
    @test occursin("found unsupported keyword argument: `kw3`", f(; kw3 = 1))
    @test occursin("perhaps you meant `kw1` or `kw2`", f(; kw3 = 1))
    @show f(; kw3 = 1)
end

@testitem "Customizing behavior" begin
    using ArguMend: @argumend, SuggestiveMethodError

    @argumend n_suggestions = 1 cutoff = 0.5 function f(; abc1 = 1, abc2 = 2, abc3 = 3)
        return abc1 + abc2 + abc3
    end
    @test f(; abc1 = 1, abc2 = 1, abc3 = 1) == 3
    @test_throws SuggestiveMethodError f(; abc = 1)
    if VERSION >= v"1.9"
        @test_throws "found unsupported keyword argument: `abc`, perhaps you meant `abc1`" f(;
            abc = 1,
        )
        # Make sure abc2 is not suggested

        msg = try
            f(; abc = 1)
        catch e
            sprint((io, e) -> showerror(io, e), e)
        end
        @test occursin("abc1", msg)
        @test !occursin("abc2", msg)
        @test !occursin("abc3", msg)
    end

    @argumend cutoff = 1.0 function g(; abc1 = 1, abc2 = 2, abc3 = 3)
        return abc1 + abc2 + abc3
    end
    msg = try
        g(; abc = 1)
    catch e
        sprint((io, e) -> showerror(io, e), e)
    end

    # Now, nothing should show up:
    @test !occursin("abc1", msg)
    @test !occursin("abc2", msg)
    @test !occursin("abc3", msg)
end


function _validate_argumend(fdef)
    if !haskey(fdef, :kwargs) || isempty(fdef[:kwargs])
        throw(
            ArguMendMacroError(
                "syntax error: could not find any keywords in function definition",
            ),
        )
    end
    if any(kw -> kw isa Expr && kw.head == :(...), fdef[:kwargs])
        throw(
            ArguMendMacroError(
                "syntax error: keyword splatting is not permitted in an `@argumend` function definition",
            ),
        )
    end
    return nothing
end

@testitem "Error checking" begin
    using ArguMend
    using ArguMend: ArguMendMacroError, argumend

    @test_throws ArguMendMacroError argumend(:(f() = nothing))
    @test_throws ArguMendMacroError argumend(:(f(; kws...) = kws))

    if VERSION >= v"1.9"
        @test_throws "could not find any keywords" argumend(:(f() = nothing))
        @test_throws "keyword splatting is not permitted" argumend(:(f(; kws...) = kws))
    end
end

Base.@kwdef struct Match
    a_start::Int
    b_start::Int
    len::Int
end


"""Find first maximal matching sequence between a and b"""
function longest_match(a, b)
    match = Match(a_start = firstindex(b), b_start = firstindex(a), len = 0)
    for a_start in eachindex(a), b_start in eachindex(b)
        len = 0
        a_i = a_start
        b_i = b_start
        while a_i <= lastindex(a) && b_i <= lastindex(b) && a[a_i] == b[b_i]
            len += 1
            a_i = nextind(a, a_i)
            b_i = nextind(b, b_i)
        end
        if len > match.len
            match = Match(; a_start = a_start, b_start = b_start, len)
        end
    end
    return match
end

@testitem "Test longest match" begin
    using ArguMend: longest_match, Match

    @test longest_match("abc", "bcd") == Match(a_start = 2, b_start = 1, len = 2)

    # Prefers the first match:
    @test longest_match("1234", "12 34") == Match(a_start = 1, b_start = 1, len = 2)

    # No match will have len 0
    @test longest_match("1", "2") == Match(a_start = 1, b_start = 1, len = 0)

    # Works for other collections
    @test longest_match([1, 2, 3], [2, 3, 4, 5, 6, 1, 2, 3]) ==
          Match(a_start = 1, b_start = 6, len = 3)
end

"""
Return a vector of all matching subsequences
"""
function all_matching_subsequences(a::Vector, b::Vector)
    matches = _all_matching_subsequences(a, b)
    matches = filter(m -> m.len > 0, matches)
    # Same sorting to python difflib:
    matches = sort(
        matches,
        by = m -> (m.a_start, m.a_start + m.len, m.b_start, m.b_start + m.len),
    )
    return matches
end
function all_matching_subsequences(a, b)
    return all_matching_subsequences(collect(a), collect(b))
end
# ^Convert to Vector{Char}, to avoid the weird indices
# of unicode strings

function _all_matching_subsequences(a::Vector, b::Vector; offsets = (a = 0, b = 0))
    # We compute this via recursion on the remaining
    # subsequences after the largest match is removed.

    # Most kwargs are pretty short, and this will be evaluated
    # only in the scope of bad function signatures,
    # so we can just brute force it.
    if isempty(a) || isempty(b)
        return Match[]
    end
    match = longest_match(a, b)
    if match.len == 0
        return Match[]
    end
    matches = [
        Match(;
            a_start = match.a_start + offsets.a,
            b_start = match.b_start + offsets.b,
            len = match.len,
        ),
    ]
    a_start = match.a_start
    b_start = match.b_start
    a_end = a_start + match.len - 1
    b_end = b_start + match.len - 1

    # Left side
    if a_start > firstindex(a) && b_start > firstindex(b)
        matches = vcat(
            matches,
            _all_matching_subsequences(
                a[firstindex(a):prevind(a, a_start)],
                b[firstindex(b):prevind(b, b_start)];
                offsets = offsets,
            ),
        )
    end
    # Right side
    if a_end < lastindex(a) && b_end < lastindex(b)
        matches = vcat(
            matches,
            _all_matching_subsequences(
                a[nextind(a, a_end):lastindex(a)],
                b[nextind(b, b_end):lastindex(b)];
                offsets = (a = offsets.a + match.len, b = offsets.b + match.len),
            ),
        )
    end
    return matches
end

@testitem "Test all matching subsequences" begin
    using ArguMend: all_matching_subsequences, Match

    @test all_matching_subsequences("abc", "abc") ==
          [Match(a_start = 1, b_start = 1, len = 3)]
    @test all_matching_subsequences([1, 2, 3], [1, 2, 3]) ==
          [Match(a_start = 1, b_start = 1, len = 3)]
    @test all_matching_subsequences("aabc", "abababc") == [
        Match(a_start = 1, b_start = 1, len = 1),
        Match(a_start = 2, b_start = 5, len = 3),
    ]

    # No Matches
    @test isempty(all_matching_subsequences("abc", "def"))
    @test isempty(all_matching_subsequences([1, 2, 3], [4, 5, 6]))

    # Overlapping matches
    @test all_matching_subsequences("aaaa", "aa") ==
          [Match(a_start = 1, b_start = 1, len = 2)]
    @test all_matching_subsequences("aaaa", "a a") == [
        Match(a_start = 1, b_start = 1, len = 1),
        Match(a_start = 2, b_start = 3, len = 1),
    ]
    @test all_matching_subsequences([1, 2, 1, 2], [1, 2]) ==
          [Match(a_start = 1, b_start = 1, len = 2)]

    # Unicode strings
    @test all_matching_subsequences("α", "αβ") == [Match(a_start = 1, b_start = 1, len = 1)]

    # Length should treat unicode the same as ASCII, which
    # is unlike standard Julia strings! This is so that
    # matching does not act weirdly when kwargs have unicode.
    @test all_matching_subsequences("αβγ", "αβg") ==
          [Match(a_start = 1, b_start = 1, len = 2)]

    # Edge Cases
    @test isempty(all_matching_subsequences("", "abc"))
    @test isempty(all_matching_subsequences("abc", ""))
    @test all_matching_subsequences("a", "a") == [Match(a_start = 1, b_start = 1, len = 1)]
end


function similarity_ratio(a, b)
    if isempty(a) && isempty(b)
        return 1.0
    end
    matches = all_matching_subsequences(a, b)
    sum_len = sum(m -> m.len, matches; init = 0)
    return 2.0 * sum_len / (length(a) + length(b))
end

@testitem "Test similarity ratio" begin
    using ArguMend: similarity_ratio

    @test similarity_ratio("abc", "abc") == 1.0
    @test similarity_ratio("abc", "def") == 0.0
    @test similarity_ratio("abcd", "bcde") == 0.75

    @test similarity_ratio("ab ab", "ababa") == 0.8

    # Edge cases
    @test similarity_ratio("", "") == 1.0
end


"""
    extract_close_matches(key, candidates; n=3, cutoff=0.6)

Finds and returns up to `n` close matches from `candidates` for a given `key` based on a similarity ratio.
The similarity ratio is calculated using the `similarity_ratio` function, which compares matching subsequences.

# Arguments
- `key`: The string or sequence for which close matches are sought.
- `candidates`: An array of strings or sequences against which the `key` is compared.

# Optional keywords
- `n`: The maximum number of close matches to return (default is 3).
- `cutoff`: The minimum similarity ratio required for a candidate to be considered a close match (default is 0.6).

# Returns
- An array of up to `n` candidates that have a similarity ratio above the `cutoff`.

# Examples

```julia
julia> mistyped_kw = "iterations";

julia> candidate_kws = ["niterations", "ncycles_per_iteration", "niterations_per_cycle", "abcdef", "iter"];

julia> extract_close_matches(mistyped_kw, candidate_kws)
["niterations", "niterations_per_cycle"]
```
"""
function extract_close_matches(key, candidates; n = 3, cutoff = 0.6)
    candidate_scores = [
        (; candidate, score = similarity_ratio(key, candidate)) for candidate in candidates
    ]
    filter!(c -> c.score >= cutoff, candidate_scores)
    sort!(candidate_scores, by = c -> c.score, rev = true)
    remaining_candidates = [c.candidate for c in candidate_scores]
    if length(remaining_candidates) <= n
        return remaining_candidates
    else
        return remaining_candidates[1:n]
    end
end


@testitem "Test close matches" begin
    using ArguMend: extract_close_matches

    mistyped_kw = "iterations"
    candidate_kws =
        ["niterations", "ncycles_per_iteration", "niterations_per_cycle", "abcdef", "iter"]

    @test extract_close_matches(mistyped_kw, candidate_kws) ==
          ["niterations", "niterations_per_cycle"]
end

end
