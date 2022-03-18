using PlantGeom
using Test
using ReferenceTests

using ColorSchemes
using Meshes
using StaticArrays
using MultiScaleTreeGraph
using CoordinateTransformations
using LinearAlgebra
using CairoMakie
using MeshViz

# Update the reference plots (do only when you know awhat you are doing!):
# include("makes_references.jl")

@testset "Read OPF" begin
    include("test-read_opf.jl")
end

@testset "Write OPF" begin
    include("test-read_opf.jl")
end

@testset "Makie recipes" begin
    include("test-makie-recipes.jl")
end

using RecipesBase
using Plots # Add this dependency because else the tests on plot recipes return an error (I don't know why)
@testset "Plots.jl recipes" begin
    include("test-plots-recipe.jl")
end
