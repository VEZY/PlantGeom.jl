Makie.plottype(::MultiScaleTreeGraph.Node) = Viz{<:Tuple{MultiScaleTreeGraph.Node}}

"""
    viz(opf::MultiScaleTreeGraph.Node; kwargs...)
    viz!(opf::MultiScaleTreeGraph.Node; kwargs...)

Vizualise the 3D geometry of an MTG (usually read from an OPF). This function search for
the `:geometry` attribute in each node of the MTG, and build the vizualisation using the
`mesh` field, or the reference meshes and the associated transformation matrix if missing.

This function needs 3D information first.

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
# Colors as a vector (no missing values allowed here):
viz(meshes, color = [:burlywood4, :springgreen4, :burlywood4])
```
"""
viz, viz!

function Makie.plot!(plot::Viz{<:Tuple{MultiScaleTreeGraph.Node}})
    plot_opf(plot)
end
