"""
    colorbar(parent, plotobject, kwargs...)

Add a colorbar based on the attribute chose to color the plot. plotobject must be a plot of
an MTG colored by an attribute. Use Makie.Colorbar for any other use case instead.
"""
function colorbar(parent, plotobject; kwargs...)
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

    # Because we extend the `Viz` type, we need to check if the user has given a color range.
    # If we defined our own e.g. `PlantViz` type, we could have defined a `color_range` field in it directly.
    if hasproperty(plotobject.attributes, :color_range)
        colorbar_limits = plotobject.attributes.color_range[]
    else
        # Get the attribute values without nothing values:    
        colorbar_limits = attribute_range(plotobject.converted[1][], plotobject.attributes.color[])
    end

    Makie.Colorbar(
        parent,
        label=string(plotobject.attributes.color[]),
        colormap=get_colormap(Observables.to_value(plotobject.attributes.colorscheme)),
        limits=Float64.(colorbar_limits);
        kwargs...
    )
end
