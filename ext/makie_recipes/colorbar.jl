"""
    colorbar(parent, plotobject, kwargs...)

Add a colorbar based on the attribute chose to color the plot. plotobject must be a plot of
an MTG colored by an attribute. Use Makie.Colorbar for any other use case instead.

# Arguments

- `parent`: parent scene
- `plotobject`: plot object to add the colorbar to
- `kwargs`: keyword arguments to pass to Makie.Colorbar, *e.g.* `label="Length (m)"`

# Example

```julia
using GLMakie, MultiScaleTreeGraph, PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
opf = read_opf(file)

f, ax, p = viz(opf, color=:Length)
colorbar(f[1, 2], p)
f
"""
function PlantGeom.colorbar(parent, plotobject; kwargs...)
    color = plotobject.attributes.color
    mtg = plotobject[1]

    if !(typeof(mtg[]) <: MultiScaleTreeGraph.Node)
        error("This is not a plot of an MTG. Use Makie.Colorbar instead.")
    end

    if !(color[] in get_attributes(mtg[]))
        error(
            "The plot must be colored by an MTG attribute for making a colorbar.",
            "Use Makie.Colorbar instead."
        )
    end

    # Because we extend the `Viz` type, we need to check if the user has given a color range.
    # If we defined our own e.g. `PlantViz` type, we could have defined a `colorrange` field in it directly.

    if hasproperty(plotobject.attributes, :colorrange) && (!isa(plotobject.attributes.colorrange, Observables.Observable) || plotobject.attributes.colorrange[] !== nothing)
        if isa(plotobject.attributes.colorrange, Observables.Observable)
            # colorbar_limits = Unitful.ustrip.(plotobject.attributes.colorrange[])
            colorbar_limits = Makie.lift(x -> Unitful.ustrip.(x), plotobject.attributes.colorrange)
        else
            colorbar_limits = Observables.Observable(plotobject.attributes.colorrange)
        end
    else
        # Get the attribute values without nothing values:    
        colorbar_limits = Makie.@lift PlantGeom.attribute_range($mtg, $color, ustrip=true)
    end
    colormap = Makie.lift(get_colormap, plotobject.attributes.colormap)

    Makie.Colorbar(
        parent,
        colormap=colormap,
        limits=colorbar_limits;
        kwargs...
    )
end
