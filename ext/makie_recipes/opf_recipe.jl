Makie.plottype(::MultiScaleTreeGraph.Node) = MeshesMakieExt.Viz{<:Tuple{MultiScaleTreeGraph.Node}}

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
    - `colormap`: The colorscheme to be used for the plot. Can be a Symbol or a ColorScheme. 
    - `segmentcolor`: The color to be used for the facets. Should be a colorant or a symbol of color.
    - `showsegments`: A boolean indicating whether the facets should be shown or not.
    - `color_missing=RGBA(0, 0, 0, 0.3)`: The color to be used for missing values. Should be a colorant or a symbol of color.
    - `index`: An integer giving the index of the attribute value to be vizualised. This is useful when the attribute is a vector of values for *e.g.* each timestep.
    - `color_cache_name`: The name of the color cache. Should be a string (default to a random string).
    - `filter_fun`: A function to filter the nodes to be plotted. Should be a function taking a node as argument and returning a boolean.
    - `symbol`: Plot only nodes with this symbol. Should be a String or a vector of.
    - `scale`: Plot only nodes with this scale. Should be an Int or a vector of.
    - `link`: Plot only nodes with this link. Should be a String or a vector of.
    
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
transform!(opf, zmax => :z_max, ignore_nothing = true)
viz(opf, color = :z_max)

# One color for each vertex of the refmesh 1:
using Meshes
vertex_color = get_color(1:nvertices(get_ref_meshes(opf))[1], [1,nvertices(get_ref_meshes(opf))[1]])
viz(opf, color = Dict(1 => vertex_color))

# Or even coloring by the value of the Z coordinates of each vertex:
transform!(opf, :geometry => (x -> [Meshes.coords(i).z for i in Meshes.vertices(x.mesh)]) => :z, ignore_nothing = true)
viz(opf, color = :z, showsegments = true)

f,a,p = viz(opf, color = :z, showsegments = true)
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

function Makie.plot!(plot::MeshesMakieExt.Viz{<:Tuple{MultiScaleTreeGraph.Node}})
    @warn "The `viz!` function is deprecated, use `plantviz!` instead."
    plot_opf(plot, :object)
end

# Implementing our own plot recipe for PlantViz (plantviz and plantviz!):
Makie.@recipe PlantViz (mtg,) begin
    color = :slategray3
    alpha = nothing
    colormap = nothing
    colorrange = nothing
    showsegments = false
    segmentcolor = :gray30
    segmentsize = 1.5
    showpoints = false
    pointmarker = :circle
    pointcolor = :gray30
    pointsize = 4 #  use `pointsize = @inherit markersize` instead?
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
end

Makie.args_preferred_axis(mtg::MultiScaleTreeGraph.Node) = Makie.LScene

function Makie.plot!(plot::PlantViz{<:Tuple{MultiScaleTreeGraph.Node}})
    plot_opf(plot, :mtg)
end
