# This is a makie recipe to plot the mtg nodes and connections.
@Makie.recipe(Diagram) do scene
    Makie.Attributes(
        color = :black,
        colormap = :viridis,
        edge_color = nothing,
        color_missing = RGBA(0, 0, 0, 0.3)
    )
end


"""
    diagram(opf::MultiScaleTreeGraph.Node; kwargs...)
    diagram!(opf::MultiScaleTreeGraph.Node; kwargs...)

Make a diagram of the MTG tree, paired with a `Makie.jl` backend.

See also [`apply_recipe`](@ref) for the same plot with a `Plots.jl` backend.

The main attributes are:

- color: the color of the nodes
- colormap: the colormap used if the color uses an attribute. By default it uses viridis.
Must be a ColorScheme from [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/)
or a Symbol with its name.


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
    edge_color = p[:edge_color][]
    colormap = get_colormap(p[:colormap][])

    if edge_color === nothing
        edge_color = color
    end

    df_coordinates, color, edge_color, text_color =
        mtg_XYZ_color(mtg, color, edge_color, colormap, color_missing = p[:color_missing][])

    Makie.scatter!(
        p,
        df_coordinates.XX,
        df_coordinates.YY,
        df_coordinates.ZZ,
        color = color,
        colormap = colormap
    )

    Makie.text!(
        p,
        string.(df_coordinates.id),
        position = [Makie.Point3f(df_coordinates.XX[i], df_coordinates.YY[i], df_coordinates.ZZ[i]) for i in 1:size(df_coordinates, 1)],
        color = text_color,
        offset = (5, 5)
    )

    for i in 2:size(df_coordinates, 1)
        Makie.lines!(
            p,
            [df_coordinates.XX_from[i], df_coordinates.XX[i]],
            [df_coordinates.YY_from[i], df_coordinates.YY[i]],
            [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]],
            color = edge_color[i]
        )
    end

    p
end
