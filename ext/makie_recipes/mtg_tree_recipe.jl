# This is a makie recipe to plot the mtg nodes and connections.
Makie.@recipe(Diagram) do scene
    Makie.Attributes(
        color=:black,
        colormap=:viridis,
        edge_color=nothing,
        color_missing=RGBA(0, 0, 0, 0.3)
    )
end


function Makie.plot!(p::Diagram{<:Tuple{MultiScaleTreeGraph.Node{<:MultiScaleTreeGraph.AbstractNodeMTG,T}} where {T}})

    mtg = p[1][]
    color = p[:color][]
    edge_color = p[:edge_color][]
    colormap = get_colormap(p[:colormap][])

    if edge_color === nothing
        edge_color = color
    end

    df_coordinates, color, edge_color, text_color =
        PlantGeom.mtg_XYZ_color(mtg, color, edge_color, colormap, color_missing=p[:color_missing][])

    positions = [Makie.Point3f(df_coordinates.XX[i], df_coordinates.YY[i], df_coordinates.ZZ[i]) for i in 1:size(df_coordinates, 1)]
    Makie.scatter!(
        p,
        positions,
        color=color,
        colormap=colormap
    )

    Makie.text!(
        p,
        string.(df_coordinates.id),
        position=positions,
        color=text_color,
        offset=(5, 5)
    )

    for i in 2:size(df_coordinates, 1)
        Makie.lines!(
            p,
            [df_coordinates.XX_from[i], df_coordinates.XX[i]],
            [df_coordinates.YY_from[i], df_coordinates.YY[i]],
            [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]],
            color=edge_color[i]
        )
    end

    p
end
