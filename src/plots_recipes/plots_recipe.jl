RecipesBase.@recipe function f(mtg::MultiScaleTreeGraph.Node; mode = "2d")
    MultiScaleTreeGraph.branching_order!(mtg)
    df_coordinates = mtg_coordinates_df(mtg, force = true)
    df_coordinates[!, :branching_order] = descendants(mtg, :branching_order, self = true)

    x = df_coordinates.XX
    y = df_coordinates.YY
    z = df_coordinates.ZZ

    for i in 2:size(df_coordinates, 1)
        x2 = [df_coordinates.XX_from[i], df_coordinates.XX[i]]
        y2 = [df_coordinates.YY_from[i], df_coordinates.YY[i]]
        z2 = [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]]

        RecipesBase.@series begin
            label := ""
            seriescolor := :black
            if mode == "2d"
                seriestype := :line
                x2, y2
            else
                seriestype := :line3d
                x2, z2, y2
            end
        end
    end

    RecipesBase.@series begin
        label := ""
        seriescolor := :viridis
        marker_z := df_coordinates.branching_order
        colorbar_entry := false
        hover := string.(
            "name: `node_", df_coordinates.id,
            "`, link: `", df_coordinates.link,
            "`, symbol: `", df_coordinates.symbol,
            "`, index: `", df_coordinates.index, "`"
        )

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

# Examples

```julia
using PlantGeom, Plots
plotlyjs()

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
# file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")

opf = read_opf(file)

plot(opf)
```
"""
RecipesBase.apply_recipe
