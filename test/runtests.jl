using PlantGeom
using Test

using ColorSchemes
using Meshes
using StaticArrays
using MultiScaleTreeGraph
using CoordinateTransformations
using LinearAlgebra

@testset "Read OPF" begin
    include("test-read_opf.jl")
end

using RecipesBase
using Plots # Add this dependency because else the tests on plot recipes return an error (I don't know why)
@testset "Plots.jl recipes" begin
    include("test-plots-recipe.jl")
end
