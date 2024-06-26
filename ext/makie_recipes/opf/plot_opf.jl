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
    colorant = Makie.@lift PlantGeom.get_mtg_color($color, $opf)

    plot_opf(colorant, plot)
    #? NB: implement scale / symbol / link / filter_fun filtering to be able to plot only
    #? a subset of the plant/scene. This will be especially usefull when we have different
    #? kind of geometries at different scales of representation.
end

# Case where the color is a colorant (e.g. `:red`, or `RGB(0.1,0.5,0.1)`):
function plot_opf(colorant::Observables.Observable{T}, plot) where {T<:Colorant}
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")

    MultiScaleTreeGraph.traverse!(plot[:object][]; filter_fun=node -> node[:geometry] !== nothing) do node
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
end

# Case where the color is a color for each reference mesh:
function plot_opf(colorant::Observables.Observable{T}, plot) where {T<:Union{RefMeshColorant,DictRefMeshColorant,DictVertexRefMeshColorant}}
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")

    opf = plot[:object]

    ref_meshes = get_ref_meshes(opf[])
    # Make the plot, case where the color is a color for each reference mesh:
    MultiScaleTreeGraph.traverse!(opf[]; filter_fun=node -> node[:geometry] !== nothing) do node
        node[color_attr_name] = Makie.@lift color_from_refmeshes($colorant, node, ref_meshes)
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
end

function color_from_refmeshes(color::Union{RefMeshColorant,DictRefMeshColorant,DictVertexRefMeshColorant}, node, ref_meshes)
    color.colors[PlantGeom.get_ref_mesh_index!(node, ref_meshes)]
end

# Case where the color is an attribute of the MTG:
function plot_opf(colorant::Observables.Observable{AttributeColorant}, plot)
    if hasproperty(plot, :color_cache_name)
        color_attr_name = plot[:color_cache_name]
    else
        # Set the value of the cached color attribute (will be written in the MTG!)
        # This is usefull when we make several plots at once and need different colors at the same time (e.g. plotting the same plant on two different days).
        color_attr_name = MultiScaleTreeGraph.cache_name(string(UUIDs.uuid4()))
    end

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
    if hasproperty(plot, :color_vertex)
        color_vertex = plot[:color_vertex]
    else
        # Get the attribute values without nothing values:    
        color_vertex = Observables.Observable(false)
    end
    if hasproperty(plot, :color_missing)
        color_missing = plot[:color_missing]
    else
        # Get the attribute values without nothing values:    
        color_missing = Observables.Observable(RGBA(0, 0, 0, 0.3))
    end
    if hasproperty(plot, :colorrange) && (!isa(plot[:colorrange], Observables.Observable) || plot[:colorrange][] !== nothing)
        color_range = plot[:colorrange]
    else
        # Get the attribute values without nothing values:    
        color_range = Makie.@lift PlantGeom.attribute_range($opf, $colorant, ustrip=true)
    end

    if hasproperty(plot, :index)
        hasproperty(plot, :color_vertex) && error("The `index` argument can only be used when the colors are given for each mesh, not each vertex.")
        index = plot[:index]
    else
        # The plotting index is always nothing if the colors are given for each vertex
        # in the meshes. Otherwise, it is always the first index:
        index = Makie.lift(x -> x ? nothing : 1, color_vertex)
    end

    # Make the plot, case where the color is a color for each reference mesh:
    MultiScaleTreeGraph.traverse!(opf[]; filter_fun=node -> node[:geometry] !== nothing) do node
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
end

