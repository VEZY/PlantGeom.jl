"""
    colorbar(parent, plotobject, kwargs...)

Add a colorbar based on the attribute chose to color the plot. plotobject must be a plot of
an MTG colored by an attribute. Use Makie.Colorbar for any other use case instead.
"""
function colorbar(parent, plotobject, kwargs...)
    color = plotobject.attributes.color[]
    mtg = plotobject.converted[1][]

    if !(typeof(mtg) <: MultiScaleTreeGraph.Node)
        error("This is not a plot of an MTG. Use Makie.Colorbar instead.")
    end

    if !(color in get_attributes(mtg))
        error(
            "The plot must be colored by an MTG attribute for making a colorbar.",
            "Use Makie.Colorbar instead."
        )
    end

    range_val = extrema(
        descendants(
            plotobject.converted[1][],
            plotobject.attributes.color[],
            ignore_nothing = true
        )
    )
    Makie.Colorbar(
        parent,
        label = string(plotobject.attributes.color[]),
        colormap = plotobject.attributes.colormap,
        limits = Float64.(range_val),
        kwargs...
    )
end
