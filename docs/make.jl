using ArguMend
using Documenter

DocMeta.setdocmeta!(ArguMend, :DocTestSetup, :(using ArguMend); recursive = true)

readme = open(dirname(@__FILE__) * "/../README.md") do io
    read(io, String)
end

# We replace every instance of <img src="IMAGE" ...> with ![](IMAGE).
readme = replace(readme, r"<img src=\"([^\"]+)\"[^>]+>.*" => s"![](\1)")

# Then, we remove any line with "<div" on it:
readme = replace(readme, r"<[/]?div.*" => s"")

# Finally, we read in file docs/src/index_base.md:
index_base = open(dirname(@__FILE__) * "/src/index_base.md") do io
    read(io, String)
end

# And then we create "/src/index.md":
open(dirname(@__FILE__) * "/src/index.md", "w") do io
    write(io, readme)
    write(io, "\n")
    write(io, index_base)
end

makedocs(;
    modules = [ArguMend],
    authors = "MilesCranmer <miles.cranmer@gmail.com> and contributors",
    repo = "https://github.com/MilesCranmer/ArguMend.jl/blob/{commit}{path}#{line}",
    sitename = "ArguMend.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://astroautomata.com/ArguMend.jl",
        edit_link = "master",
        assets = String[],
    ),
    pages = ["Home" => "index.md", "API" => "api.md"],
    warnonly = [:missing_docs],
)

deploydocs(; repo = "github.com/MilesCranmer/ArguMend.jl", devbranch = "master")
