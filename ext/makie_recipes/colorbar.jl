"""
    colorbar(parent, plotobject, kwargs...)

Like Makie.Colorbar but faster (does not re-resolve the whole coloring).

# Arguments

- `parent`: parent scene
- `plotobject`: plot object to add the colorbar to
- `kwargs`: keyword arguments to pass to Makie.Colorbar, *e.g.* `label="Length (m)"`

# Example

```julia
using GLMakie, MultiScaleTreeGraph, PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
opf = read_opf(file)

f, ax, p = plantviz(opf, color=:Length)
colorbar(f[1, 2], p)
f
"""
function PlantGeom.colorbar(parent, plotobject; kwargs...)
    Makie.Colorbar(
        parent,
        colormap=Makie.ComputePipeline.get_observable!(plotobject[:colormap_resolved]),
        limits=Makie.ComputePipeline.get_observable!(plotobject[:colorrange_resolved]);
        kwargs...
    )
end
