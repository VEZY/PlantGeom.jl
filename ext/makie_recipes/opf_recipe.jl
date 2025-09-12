# Implementing our own plot recipe for PlantViz (plantviz and plantviz!):
Makie.@recipe PlantViz (mtg,) begin
    color = nothing
    colormap = nothing
    colorrange = nothing
    colorscale = identity
    alpha = 1.0
    highclip = Makie.automatic
    lowclip = Makie.automatic
    nan_color = :transparent
    "An integer giving the index of the attribute value to be vizualised. This is useful when the attribute is a vector of values for *e.g.* each timestep."
    index = nothing
    "The name of the color cache. Should be a string (default to a random string)."
    color_cache_name = nothing
    "The color to be used for missing values. Should be a colorant or a symbol of color."
    color_missing = RGBA(0, 0, 0, 0.3)
    "Filter the MTG nodes to be plotted by symbol"
    symbol = nothing
    "Filter the MTG nodes to be plotted using a function that takes a node as argument and returns a boolean"
    filter_fun = nothing
    "Filter the MTG nodes to be plotted by scale"
    scale = nothing
    "Filter the MTG nodes to be plotted by link"
    link = nothing
    visible = true
    "Cache the meshes computations for speeding-up plotting with only changes in coloring."
    cache = true
end

Makie.args_preferred_axis(mtg::MultiScaleTreeGraph.Node) = Makie.LScene

function Makie.plot!(plot::PlantViz{<:Tuple{MultiScaleTreeGraph.Node}})
    plot_opf(plot, :mtg)
end

# To be able to call `Makie.Colorbar(fig[1,2], p)` directly.
function Makie.extract_colormap(plot::PlantViz{<:Tuple{MultiScaleTreeGraph.Node}})
    mtg_name = hasproperty(plot, :mtg) ? :mtg : :object
    attr_value = plot.colorant[].color

    attribute_values = descendants(plot[mtg_name][], attr_value; ignore_nothing=true, self=true)
    if first(attribute_values) isa AbstractVector
        attribute_values = map(x -> Unitful.ustrip(getindex(x, plot.index_resolved[])), attribute_values)
    else
        attribute_values = Unitful.ustrip.(attribute_values)
    end

    return Makie.ColorMapping(
        attribute_values,
        Makie.ComputePipeline.get_observable!(plot.vertex_colors),
        Makie.ComputePipeline.get_observable!(plot.colormap_resolved),
        Makie.ComputePipeline.get_observable!(plot.colorrange_resolved),
        Makie.ComputePipeline.get_observable!(plot.colorscale),
        Makie.ComputePipeline.get_observable!(plot.alpha),
        Makie.ComputePipeline.get_observable!(plot.highclip),
        Makie.ComputePipeline.get_observable!(plot.lowclip),
        Makie.ComputePipeline.get_observable!(plot.nan_color),
    )
end