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


"""Find longest matching sequence between a and b"""
function longest_match(a, b)
    matches = all_matching_subsequences(a, b)
    max_len = maximum(m -> m.len, matches; init=0)
    if max_len == 0
        return Match(a_start=firstindex(a), b_start=firstindex(b), len=0)
    else
        return first(filter(m -> m.len == max_len, matches))
    end
end

@testitem "Test longest match" begin
    using ArguMend: longest_match, Match

    @test longest_match("abc", "bcd") == Match(a_start=2, b_start=1, len=2)

    # Prefers the first match:
    @test longest_match("1234", "12 34") == Match(a_start=1, b_start=1, len=2)

    # No match will have len 0
    @test longest_match("1", "2") == Match(a_start=1, b_start=1, len=0)

    # Works for other collections
    @test longest_match([1, 2, 3], [2, 3, 4, 5, 6, 1, 2, 3]) ==
          Match(a_start=1, b_start=6, len=3)
end

"""
Return a vector of all matching subsequences

This will skip subsequences which are completely
contained in a larger subsequence, and offset
at the same distance.
"""
function all_matching_subsequences(a::AbstractVector, b::AbstractVector)
    # Most kwargs are pretty short, and this will be evaluated
    # only in the scope of bad function signatures,
    # so we can just brute force it.
    matches = Match[]
    for a_start in eachindex(a), b_start in eachindex(b)
        already_included = any(matches) do m
            # First, check if same offset from start
            # a previous sequence, and contained within the
            # matching length
            within_a = a_start - m.a_start < m.len
            within_b = b_start - m.b_start < m.len
            same_distance = (a_start - m.a_start) == (b_start - m.b_start)
            return within_a && within_b && same_distance
        end
        if already_included
            continue
        end
        len = 0
        a_i = a_start
        b_i = b_start
        while a_i <= lastindex(a) && b_i <= lastindex(b) && a[a_i] == b[b_i]
            len += 1
            a_i = nextind(a, a_i)
            b_i = nextind(b, b_i)
        end
        if len > 0
            push!(matches, Match(; a_start, b_start, len))
        end
    end
    return matches
end

function all_matching_subsequences(a::AbstractString, b::AbstractString)
    # Convert to Vector{Char}, to avoid the weird indices
    # of unicode strings
    return all_matching_subsequences(collect(a), collect(b))
end

@testitem "Test all matching subsequences" begin
    using ArguMend: all_matching_subsequences, Match

    @test all_matching_subsequences("abc", "abc") == [Match(a_start=1, b_start=1, len=3)]
    @test all_matching_subsequences([1, 2, 3], [1, 2, 3]) == [Match(a_start=1, b_start=1, len=3)]
    @test all_matching_subsequences("abc", "abababc") == [
        Match(a_start=1, b_start=1, len=2),
        Match(a_start=1, b_start=3, len=2),
        Match(a_start=1, b_start=5, len=3),
    ]

    # No Matches
    @test isempty(all_matching_subsequences("abc", "def"))
    @test isempty(all_matching_subsequences([1, 2, 3], [4, 5, 6]))

    # Overlapping matches
    @test all_matching_subsequences("aaaa", "aa") == [
        Match(a_start=1, b_start=1, len=2),
        Match(a_start=1, b_start=2, len=1),
        Match(a_start=2, b_start=1, len=2),
        Match(a_start=3, b_start=1, len=2),
        Match(a_start=4, b_start=1, len=1),
    ]
    @test all_matching_subsequences([1, 2, 1, 2], [1, 2]) == [
        Match(a_start=1, b_start=1, len=2),
        Match(a_start=3, b_start=1, len=2),
    ]

    # Unicode strings
    @test all_matching_subsequences("α", "αβ") == [
        Match(a_start=1, b_start=1, len=1),
    ]

    # Length should treat unicode the same as ASCII, which
    # is unlike standard Julia strings! This is so that
    # matching does not act weirdly when kwargs have unicode.
    @test all_matching_subsequences("αβγ", "αβg") == [
        Match(a_start=1, b_start=1, len=2),
    ]

    # Edge Cases
    @test isempty(all_matching_subsequences("", "abc"))
    @test isempty(all_matching_subsequences("abc", ""))
    @test all_matching_subsequences("a", "a") == [Match(a_start=1, b_start=1, len=1)]
end


function similarity_ratio(a, b)
    if isempty(a) && isempty(b)
        return 1.0
    end
    matches = all_matching_subsequences(a, b)
    sum_len = sum(m -> m.len, matches; init=0)
    return 2.0 * sum_len / (length(a) + length(b))
end

@testitem "Test similarity ratio" begin
    using ArguMend: similarity_ratio

    @test similarity_ratio("abc", "abc") == 1.0
    @test similarity_ratio("abc", "def") == 0.0
    @test similarity_ratio("abcd", "bcde") == 0.75

    # Edge cases
    @test similarity_ratio("", "") == 1.0
end

end
