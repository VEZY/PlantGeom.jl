function diagram end
function diagram! end

"""
    diagram(opf::MultiScaleTreeGraph.Node; kwargs...)
    diagram!(opf::MultiScaleTreeGraph.Node; kwargs...)

Make a diagram of the MTG tree using a `Makie.jl` backend.

!!! danger
    This function is an extension to the package. It is only available if you imported a Makie backend (*e.g.* `using GLMakie`)
    prior to `using PlantGeom`.

The main attributes are:

- color: the color of the nodes
- colormap: the colormap used if the color uses an attribute. By default it uses viridis.
Must be a ColorScheme from [ColorSchemes](https://juliagraphics.github.io/ColorSchemes.jl/stable/basics/)
or a Symbol with its name.


# Examples

```julia
using GLMakie, PlantGeom

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
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