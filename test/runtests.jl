using CairoMakie
using Meshes
using Test
using ReferenceTests
using Documenter # for doctests
using Colors, ColorSchemes
using StaticArrays
using MultiScaleTreeGraph
using LinearAlgebra
using Tables
using Unitful
using PlantGeom

# Update the reference plots (do only when you know awhat you are doing!):
# include("makes_references.jl")

@testset "Read OPF" begin
    include("test-refmesh.jl")
end

@testset "OPF files" begin
    include("test-read_opf.jl")
    include("test-write_opf.jl")
end

@testset "OPS files" begin
    include("test-read_ops_file.jl")
    include("test-read_ops.jl")
    include("test-write_ops.jl")
end

@testset "Makie recipes" begin
    include("test-makie-recipes.jl")
end

using RecipesBase
using Plots # Add this dependency because else the tests on plot recipes return an error (I don't know why)
@testset "Plots.jl recipes" begin
    include("test-plots-recipe.jl")
end

include("test-simplify_geometry.jl")

if VERSION >= v"1.10"
    # Some formating changed in Julia 1.10, e.g. @NamedTuple instead of NamedTuple.
    @testset "Doctests" begin
        DocMeta.setdocmeta!(PlantGeom, :DocTestSetup, :(using PlantGeom; using MultiScaleTreeGraph; using Bonito); recursive=true)

        # Testing the doctests, i.e. the examples in the docstrings marked with jldoctest:
        doctest(PlantGeom; manual=false)
    end
end