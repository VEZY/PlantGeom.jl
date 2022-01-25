# This is a makie recipe to plot the mtg nodes and connections.

@Makie.recipe(Diagram) do scene
    Makie.Attributes(
        color = :black,
        colormap = :viridis,
    )
end


"""
    diagram(opf::MultiScaleTreeGraph.Node; kwargs...)
    diagram!(opf::MultiScaleTreeGraph.Node; kwargs...)

Make a diagram of the MTG tree, paired with a `Makie.jl` backend.

See also [`RecipesBase.apply_recipe`](@ref) for the same plot with a `Plots.jl` backend.

# Examples

```julia
using PlantGeom, GLMakie

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
# file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")

opf = read_opf(file)

diagram(opf)

# We can also color the 3d plot with several options:
# With one shared color:
diagram(opf, color = :red)

# Or colouring by opf attribute, *e.g.* using the nodes Z coordinates:
diagram(opf, color = :ZZ)
```
"""
diagram, diagram!

function Makie.plot!(p::Diagram{<:Tuple{MultiScaleTreeGraph.Node{<:AbstractNodeMTG,T}} where {T}})

    mtg = p[1][]
    color = p[:color][]
    colormap = p[:colormap][]

    if Symbol(color) in get_attributes(mtg)
        # Coloring using mtg attribute:
        df_coordinates = mtg_coordinates_df(mtg, color, force = true)
        colouring_var = df_coordinates[:, color]
        color = colouring_var ./ maximum(colouring_var)

        Makie.scatter!(
            p,
            df_coordinates.XX,
            df_coordinates.YY,
            df_coordinates.ZZ,
            color = color,
            colormap = colormap
        )
        # ?Note: could use meshscatter! instead here

        for i in 2:size(df_coordinates, 1)
            Makie.lines!(
                p,
                [df_coordinates.XX_from[i], df_coordinates.XX[i]],
                [df_coordinates.YY_from[i], df_coordinates.YY[i]],
                [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]],
                color = get(p[:colormap][], [color[i-1], color[i]])
            )
        end
    elseif typeof(color) <: Colorant || typeof(color) <: String || typeof(color) <: Symbol
        df_coordinates = mtg_coordinates_df(mtg, force = true)
        Makie.scatter!(
            p,
            df_coordinates.XX,
            df_coordinates.YY,
            df_coordinates.ZZ,
            color = p[:color]
        )
        # ?Note: could use meshscatter! instead here

        for i in 2:size(df_coordinates, 1)
            Makie.lines!(
                p,
                [df_coordinates.XX_from[i], df_coordinates.XX[i]],
                [df_coordinates.YY_from[i], df_coordinates.YY[i]],
                [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]],
                color = color
            )
        end
    else
        error(
            "color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "an MTG attribute."
        )
    end

    p
end
