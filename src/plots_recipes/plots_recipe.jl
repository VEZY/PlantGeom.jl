RecipesBase.@recipe function f(mtg::MultiScaleTreeGraph.Node;
    mode="2d",
    node_color=:black,
    colormap=:viridis,
    edge_color=nothing,
    color_missing=RGBA(0, 0, 0, 0.3)
)

    if edge_color === nothing
        edge_color = node_color
    end

    colormap = get_colormap(colormap)
    df_coordinates, node_color_in, edge_color, text_color =
        mtg_XYZ_color(mtg, node_color, edge_color, colormap, color_missing=color_missing)

    x = df_coordinates.XX
    y = df_coordinates.YY
    z = df_coordinates.ZZ

    for i in 2:size(df_coordinates, 1)
        x2 = [df_coordinates.XX_from[i], df_coordinates.XX[i]]
        y2 = [df_coordinates.YY_from[i], df_coordinates.YY[i]]
        z2 = [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]]
        edge_col = edge_color[i][1] # Plot is not compatible with line gradients

        RecipesBase.@series begin
            label := ""
            seriescolor := edge_col
            if mode == "2d"
                seriestype := :line
                x2, y2
            else
                seriestype := :line3d
                x2, z2, y2
            end
        end
    end

    hover_arg = string.(
        "name: `node_", df_coordinates.id,
        "`, link: `", df_coordinates.link,
        "`, symbol: `", df_coordinates.symbol,
        "`, index: `", df_coordinates.index, "`",
        if Symbol(node_color) in get_attributes(mtg)
            string.(", $node_color: ", df_coordinates[:, node_color])
        else
            ""
        end
    )

    RecipesBase.@series begin
        label := ""
        palette := colormap
        color := node_color_in
        # marker_z := node_color
        colorbar_entry := false
        hover := hover_arg
        if mode == "2d"
            seriestype := :scatter
            x, y
        else
            seriestype := :scatter3d
            x, z, y
        end

    end
end


"""
    plot(opf::MultiScaleTreeGraph.Node; kwargs...)
    plot!(opf::MultiScaleTreeGraph.Node; kwargs...)

Make a diagram of the MTG tree, paired with a `Plots.jl` backend.

See also [`diagram`](@ref) for the same plot with a `Makie.jl` backend.

## Attributes

- `mode = "2d"`: The mode for plotting, either "2d" or "3d"
- `node_color = :black`: the node color, can be a color or any MTG attribute
- `edge_color = node_color`: same as `node_color`, but for the edges
- `colormap = :viridis`: the colormap used for coloring
- `color_missing = RGBA(0, 0, 0, 0.3)`: The color used for missing values

# Examples

```julia
# import Pkg; Pkg.add("PlotlyJS")
using Plots, PlantGeom
plotlyjs()

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
# file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")

opf = read_opf(file)

plot(opf, node_color = :Length)
```
"""
RecipesBase.plot!, RecipesBase.plot
