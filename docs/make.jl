#!/usr/bin/env julia
#
#

if "--help" ∈ ARGS
    println("""
    docs/make.jl

    Render the `AlgorithmsInterface.jl` documentation with optional arguments

    Arguments
    * `--help`              print this help and exit without rendering the documentation
    * `--prettyurls`        toggle the pretty urls part to true, which is always set on CI
    """)
    exit(0)
end

using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(PackageSpec(; path = (@__DIR__) * "/../"))
Pkg.resolve()
Pkg.instantiate()

using Documenter, DocumenterCitations, DocumenterInterLinks
using AlgorithmsInterface

run_on_CI = (get(ENV, "CI", nothing) == "true")

bib = CitationBibliography(joinpath(@__DIR__, "src", "references.bib"); style = :alpha)
links = InterLinks()
makedocs(;
    format = Documenter.HTML(;
        prettyurls = run_on_CI || ("--prettyurls" ∈ ARGS),
        assets = [
            #    "assets/favicon.ico",
            "assets/citations.css",
            "assets/link-icons.css",
        ],
    ),
    modules = [AlgorithmsInterface],
    authors = "Ronny Bergmann, Lukas Devos, and contributors.",
    sitename = "AlgorithmsInterface.jl",
    pages = [
        "Home" => "index.md",
        "Interface" => "interface.md",
        "Stopping criteria" => "stopping_criterion.md",
        "Notation" => "notation.md",
        "References" => "references.md",
    ],
    plugins = [bib, links],
)
deploydocs(; repo = "github.com/JuliaManifolds/AlgorithmsInterface.jl", push_preview = true)
#back to main env
Pkg.activate()
