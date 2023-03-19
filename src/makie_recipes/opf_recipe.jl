Makie.plottype(::MultiScaleTreeGraph.Node) = Viz{<:Tuple{MultiScaleTreeGraph.Node}}

"""
    viz(opf::MultiScaleTreeGraph.Node; kwargs...)
    viz!(opf::MultiScaleTreeGraph.Node; kwargs...)

Vizualise the 3D geometry of an MTG (usually read from an OPF). This function search for
the `:geometry` attribute in each node of the MTG, and build the vizualisation using the
`mesh` field, or the reference meshes and the associated transformation matrix if missing.

The `:geometry` attribute is usually added by the `refmesh_to_mesh!` function first, which
can be called with the `transform!` function. See the examples below.

# Arguments

- `opf`: The MTG to be vizualised.
- `kwargs`: Additional arguments to be passed to `viz!`, wich includes: 
    - `color`: The color to be used for the plot. Can be a colorant, an attribute of the MTG (given as a Symbol), or a dictionary of colors for each reference mesh.
    - `colorscheme`: The colorscheme to be used for the plot. Can be a Symbol or a ColorScheme. 
    - `facetcolor`: The color to be used for the facets. Should be a colorant or a symbol of color.
    - `showfacets`: A boolean indicating whether the facets should be shown or not.
    - `color_missing`: The color to be used for missing values. Should be a colorant or a symbol of color.
    - `color_vertex`: A boolean indicating whether the values in `color` (if colored by attributes) are defined for each vertex of the mesh, or for each mesh.
    - `index`: An integer giving the index of the attribute value to be vizualised. This is useful when the attribute is a vector of values for *e.g.* each timestep.

Note that `color_vertex` is set to `false` by default.

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom, GLMakie

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
# file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")

opf = read_opf(file)
viz(opf)

# If you need to plot the opf several times, you better cache the mesh in the node geometry
# like so:
transform!(opf, refmesh_to_mesh!)

# Then plot it again like before, and it will be faster:
viz(opf)

# We can also color the 3d plot with several options:
# With one shared color:
viz(opf, color = :red)
# One color per reference mesh:
viz(opf, color = Dict(1 => :burlywood4, 2 => :springgreen4, 3 => :burlywood4))

# Or just changing the color of some:
viz(opf, color = Dict(1 => :burlywood4))

# Or coloring by opf attribute, e.g. using the mesh max Z coordinates (NB: need to use
# `refmesh_to_mesh!` before, see above):
transform!(opf, :geometry => (x -> zmax(x.mesh)) => :z_max, ignore_nothing = true)
viz(opf, color = :z_max)

# One color for each vertex of the refmesh 1:
using Meshes
vertex_color = get_color(1:nvertices(get_ref_meshes(opf))[1], [1,nvertices(get_ref_meshes(opf))[1]])
viz(opf, color = Dict(1 => vertex_color))

# Or even coloring by the value of the Z coordinates of each vertex:
transform!(opf, :geometry => (x -> [i.coords[3] for i in x.mesh.vertices]) => :z, ignore_nothing = true)
viz(opf, color = :z, showfacets = true)

f,a,p = viz(opf, color = :z, showfacets = true)
p[:color] = :Length
```


    viz!(ref_meshes; kwargs...)

Plot all reference meshes in a single 3d plot using Makie.

# Examples

```julia
using PlantGeom, GLMakie

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)

viz(meshes)
# With one shared color:
viz(meshes, color = :green)
# One color per reference mesh:
viz(meshes, color = Dict(1 => :burlywood4, 2 => :springgreen4, 3 => :burlywood4))
# Or just changing the color of some:
viz(meshes, color = Dict(1 => :burlywood4, 3 => :burlywood4))
# One color for each vertex of the refmesh 0:
viz(meshes, color = Dict(2 => 1:nvertices(meshes)[2]))
```
"""
viz, viz!

function Makie.plot!(plot::Viz{<:Tuple{MultiScaleTreeGraph.Node}})
    plot_opf(plot)
end
