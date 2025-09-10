"""
    plantviz(mtg::MultiScaleTreeGraph.Node; kwargs...)
    plantviz!(mtg::MultiScaleTreeGraph.Node; kwargs...)

Vizualise the 3D geometry of an MTG (usually read from an OPF). This function search for
the `:geometry` attribute in each node of the MTG, and build the vizualisation using the
reference meshes and the associated transformation matrix.

# Arguments

- `mtg`: The MTG to be vizualised.
- `kwargs`: Additional arguments to be passed to `plantviz!`, wich includes: 
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

mtg = read_opf(file)
plantviz(mtg)

# Then plot it again like before, and it will be faster:
plantviz(mtg)

# We can color the 3d plot with several options:
# With one shared color:
plantviz(mtg, color = :red)
# One color per reference mesh:
plantviz(mtg, color = Dict(1 => :burlywood4, 2 => :springgreen4, 3 => :burlywood4))

# Or just changing the color of some:
plantviz(mtg, color = Dict(1 => :burlywood4))

# Or coloring by mtg attribute, e.g. using the mesh max Z coordinates:
transform!(mtg, zmax => :z_max, ignore_nothing = true)
plantviz(mtg, color = :z_max)

# One color for each vertex of the refmesh 1:
using Meshes
vertex_color = get_color(1:nvertices(get_ref_meshes(mtg))[1], [1,nvertices(get_ref_meshes(mtg))[1]])
plantviz(mtg, color = Dict(1 => vertex_color))

# Or even coloring by the value of the Z coordinates of each vertex:
transform!(mtg, (x -> [Meshes.coords(i).z for i in Meshes.vertices(refmesh_to_mesh(x))]) => :z_vertex, filter_fun= node -> hasproperty(node, :geometry))
plantviz(mtg, color = :z, showsegments = true)

f,a,p = plantviz(mtg, color = :z, showsegments = true)
p[:color] = :Length
```


    plantviz!(ref_meshes; kwargs...)

Plot all reference meshes in a single 3d plot using Makie.

# Examples

```julia
using PlantGeom, GLMakie

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
mtg = read_opf(file)
meshes = get_ref_meshes(mtg)

plantviz(meshes)
# With one shared color:
plantviz(meshes, color = :green)
# One color per reference mesh:
plantviz(meshes, color = Dict(1 => :burlywood4, 2 => :springgreen4, 3 => :burlywood4))
# Or just changing the color of some:
plantviz(meshes, color = Dict(1 => :burlywood4, 3 => :burlywood4))
# One color for each vertex of the refmesh 0:
plantviz(meshes, color = Dict(2 => 1:nvertices(meshes)[2]))
```
"""
function plantviz end

"""
    viplantviz!(mtg; [options])

Visualize the 3D meshes of an mtg using Meshes.jl and makie.
This function adds the plot to an existing scene with `options` forwarded to [`plantviz`](@ref).
"""
function plantviz! end