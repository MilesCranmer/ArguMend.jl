module ArguMend

export @argumend

using MacroTools: splitdef, combinedef
using TestItems: @testitem

macro argumend(args...)
    return esc(argumend(args...))
end

"""Errors coming from the construction of an ArguMend function."""
struct ArguMendLoadError <: Exception
    msg::String
end

function argumend(args...)
    argumend_options, raw_fdef = args[begin:end-1], args[end]
    fdef = splitdef(raw_fdef)
    _validate_argumend(fdef)
    kwarg_strings = string.(fdef[:kwargs])
    return combinedef(fdef)
end


@testitem "Basic usage" begin
    using ArguMend

    @argumend f(; kw) = kw + 1

    # @test_throws UndefKeywordError f(kww = 2)
    # if VERSION >= v"1.9"
    #     @test_throws "did you mean" f(kww = 2)
    # end
end


function _validate_argumend(fdef)
    if !haskey(fdef, :kwargs) || isempty(fdef[:kwargs])
        throw(
            ArguMendLoadError(
                "syntax error: could not find any keywords in function definition",
            ),
        )
    end
    if any(kw -> kw isa Expr && kw.head == :(...), fdef[:kwargs])
        throw(
            ArguMendLoadError(
                "syntax error: keyword splatting is not permitted in an `@argumend` function definition",
            ),
        )
    end
    return nothing
end

@testitem "Error checking" begin
    using ArguMend
    using ArguMend: ArguMendLoadError, argumend

    @test_throws ArguMendLoadError argumend(:(f() = nothing))
    @test_throws ArguMendLoadError argumend(:(f(; kws...) = kws))

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
