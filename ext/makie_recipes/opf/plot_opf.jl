"""
    plot_opf(plot)

Actual workhorse function for plotting an OPF / MTG with geometry.

# Arguments

- `plot`: The plot object.

The plot object can have the following optional arguments:

- `color`: The color to be used for the plot. Can be a colorant, an attribute of the MTG, or a dictionary of colors for each reference mesh.
- `alpha`: The alpha value to be used for the plot. Should be a float between 0 and 1.
- `colormap`: The colorscheme to be used for the plot. Can be a Symbol or a ColorScheme.
- `colorrange`: The range of values to be used for the colormap. Should be a tuple of floats (optionally with units if *e.g.* z position).
- `segmentcolor`: The color to be used for the facets. Should be a colorant or a symbol of color.
- `showsegments`: A boolean indicating whether the facets should be shown or not.
- `segmentsize`: The size of the segments. Should be a float.
- `showpoints`: A boolean indicating whether the points should be shown or not.
- `color_missing`: The color to be used for missing values. Should be a colorant or a symbol of color.
- `color_vertex`: A boolean indicating whether the values in `color` (if colored by attributes) are defined for each vertex of the mesh, or for each mesh.
- `pointsize`: The size of the points. Should be a float.
- `index`: An integer giving the index of the attribute value to be vizualised. This is useful when the attribute is a vector of values for *e.g.* each timestep.
- `color_cache_name`: The name of the color cache. Should be a string (default to a random string).
- `filter_fun`: A function to filter the nodes to be plotted. Should be a function taking a node as argument and returning a boolean.
- `symbol`: Plot only nodes with this symbol. Should be a String or a vector of.
- `scale`: Plot only nodes with this scale. Should be an Int or a vector of.
- `link`: Plot only nodes with this link. Should be a String or a vector of.

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom, Colors

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")

opf = read_opf(file)

f, a, plot = viz(opf)
plot_opf(p)

f, a, plot = viz(opf, color=:red)
plot_opf(plot)

f, a, plot = viz(opf, color=:Length)
plot_opf(plot)

plot_opf(opf; color=Dict(1=>RGB(0.1,0.5,0.1), 2=>RGB(0.1,0.1,0.5)))

plot_opf(opf; color=:red, colormap=:viridis)

plot_opf(opf; color=:red, colormap=:viridis, segmentcolor=:red, showsegments=true)


"""
function plot_opf(plot)

    opf = plot[:object]
    color = plot[:color]

    # Get the colors for the meshes:
    colorant = Makie.@lift PlantGeom.get_mtg_color($color, opf) #! not using `$opf` as it would trigger the computation of the color again on change, which is not what we want here.

    if hasproperty(plot, :filter_fun)
        f = node -> node[:geometry] !== nothing && plot[:filter_fun][](node)
    else
        f = node -> node[:geometry] !== nothing
    end

    @show plot.attributes
    symbol = hasproperty(plot, :symbol) ? Makie.lift(x -> x, plot[:symbol]) : nothing
    scale = hasproperty(plot, :scale) ? Makie.lift(x -> x, plot[:scale]) : nothing
    link = hasproperty(plot, :link) ? Makie.lift(x -> x, plot[:link]) : nothing

    plot_opf(colorant, plot, f, symbol, scale, link)
end

# Case where the color is a colorant (e.g. `:red`, or `RGB(0.1,0.5,0.1)`):
function plot_opf(colorant::Observables.Observable{T}, plot, f, symbol, scale, link) where {T<:Colorant}
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")
    any_node_selected = Ref(false)
    MultiScaleTreeGraph.traverse!(plot[:object][]; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        any_node_selected[] = true
        # get the color based on a colormap and the normalized attribute value
        node[color_attr_name] = Makie.lift(x -> x, colorant)

        MeshesMakieExt.viz!(
            plot,
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
            segmentcolor=plot[:segmentcolor],
            showsegments=plot[:showsegments],
            segmentsize=plot[:segmentsize],
            alpha=plot[:alpha],
            colormap=plot[:colormap],
        )
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
end

# Case where the color is a vector of colors / symbols (e.g. `fill(:red, length(mtg))`):
function plot_opf(colorant::Observables.Observable{T}, plot, f, symbol, scale, link) where {T<:Union{PlantGeom.VectorColorant,PlantGeom.VectorSymbol}}
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")
    any_node_selected = Ref(false)
    i = Ref(0) # index to access the color vector

    MultiScaleTreeGraph.traverse!(plot[:object][]; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        i[] += 1
        any_node_selected[] = true
        # get the color based on a colormap and the normalized attribute value
        node[color_attr_name] = Makie.lift(x -> x.colors[i[]], colorant)
        MeshesMakieExt.viz!(
            plot,
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
            segmentcolor=plot[:segmentcolor],
            showsegments=plot[:showsegments],
            segmentsize=plot[:segmentsize],
            alpha=plot[:alpha],
            colormap=plot[:colormap],
        )
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
end

# Case where the color is a color for each reference mesh:
function plot_opf(colorant::Observables.Observable{T}, plot, f, symbol, scale, link) where {T<:Union{RefMeshColorant,DictRefMeshColorant,DictVertexRefMeshColorant}}

    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")

    opf = plot[:object]

    any_node_selected = Ref(false)
    # Make the plot, case where the color is a color for each reference mesh:
    MultiScaleTreeGraph.traverse!(opf[]; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        any_node_selected[] = true

        node[color_attr_name] = Makie.@lift color_from_refmeshes($colorant, node)
        MeshesMakieExt.viz!(
            plot,
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
            segmentcolor=plot[:segmentcolor],
            showsegments=plot[:showsegments],
            segmentsize=plot[:segmentsize],
            alpha=plot[:alpha],
            colormap=plot[:colormap],
        )
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
end

function color_from_refmeshes(color::RefMeshColorant, node)
    material_single_color(node.geometry.ref_mesh.material)
end

function color_from_refmeshes(color::Union{DictRefMeshColorant,DictVertexRefMeshColorant}, node)
    get(color.colors, get_ref_mesh_name(node), material_single_color(node.geometry.ref_mesh.material))
end

# Case where the color is an attribute of the MTG:
function plot_opf(colorant::Observables.Observable{AttributeColorant}, plot, f, symbol, scale, link)

    # Set the value of the cached color attribute (will be written in the MTG!)
    # This is usefull when we make several plots at once and need different colors at the same time (e.g. plotting the same plant on two different days).
    color_attr_name = hasproperty(plot, :color_cache_name) ? plot[:color_cache_name] : MultiScaleTreeGraph.cache_name("Color name")

    opf = plot[:object]
    colormap_ = plot[:colormap]
    colormap = Makie.@lift get_colormap($colormap_)

    # Because we extend the `Viz` type, we cannot use the standard way of getting the attribute
    # from the plot. Instead, we need to check here if the argument is given, and give the default
    # value if not.
    # Note: If we defined our own e.g. `PlantViz` type, we could have defined a `color_missing` and 
    # `colorrange` fields in it directly.

    # Are the colors given for each vertex in the meshes, or for each reference mesh?
    # Note that we can have several values if we have several timesteps too.
    color_vertex = hasproperty(plot, :color_vertex) ? plot[:color_vertex] : Observables.Observable(false)
    color_missing = hasproperty(plot, :color_missing) ? plot[:color_missing] : Observables.Observable(RGBA(0, 0, 0, 0.3))

    color_range = Makie.@lift get_color_range($(plot[:colorrange]), opf, $colorant)
    #! Important note: we use `opf` here and not `$opf` because the code below will modify the OPF, and we don't want to trigger
    #! this again on change, as it will do a stack overflow error (infinite recursion).

    if hasproperty(plot, :index)
        hasproperty(plot, :color_vertex) && error("The `index` argument can only be used when the colors are given for each mesh, not each vertex.")
        index = plot[:index]
    else
        # The plotting index is always nothing if the colors are given for each vertex
        # in the meshes. Otherwise, it is always the first index:
        index = Makie.lift(x -> x ? nothing : 1, color_vertex)
    end

    any_node_selected = Ref(false)
    # Make the plot, case where the color is a color for each reference mesh:
    MultiScaleTreeGraph.traverse!(opf[]; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        any_node_selected[] = true
        color_attribute = Makie.@lift PlantGeom.attr_colorant_name($colorant) # the attribute name used for coloring

        if node[color_attribute[]] === nothing
            node[color_attr_name] = color_missing
        else
            # get the color based on a colormap and the normalized attribute value
            node[color_attr_name] = Makie.@lift get_color(node[$color_attribute], $color_range, $index; colormap=$colormap)
        end

        MeshesMakieExt.viz!(
            plot,
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
            alpha=plot[:alpha],
            segmentcolor=plot[:segmentcolor],
            showsegments=plot[:showsegments],
            colormap=colormap,
            segmentsize=plot[:segmentsize],
        )
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
end

