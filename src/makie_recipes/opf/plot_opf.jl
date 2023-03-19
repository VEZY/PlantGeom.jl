"""
    plot_opf(plot)

Actual workhorse function for plotting an OPF / MTG with geometry.

# Arguments

- `plot`: The plot object.

The plot object can have the following optional arguments:

- `color`: The color to be used for the plot. Can be a colorant, an attribute of the MTG, or a dictionary of colors for each reference mesh.
- `colorscheme`: The colorscheme to be used for the plot. Can be a Symbol or a ColorScheme.
- `facetcolor`: The color to be used for the facets. Should be a colorant or a symbol of color.
- `showfacets`: A boolean indicating whether the facets should be shown or not.
- `color_missing`: The color to be used for missing values. Should be a colorant or a symbol of color.


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

plot_opf(opf; color=:red, colorscheme=:viridis)

plot_opf(opf; color=:red, colorscheme=:viridis, facetcolor=:red, showfacets=true)


"""
function plot_opf(plot)

    opf = plot[:object]
    color = plot[:color]

    # Get the colors for the meshes:
    colorant = Makie.@lift get_mtg_color($color, $opf)

    plot_opf(colorant, plot)
    #? NB: implement scale / symbol / link / filter_fun filtering to be able to plot only
    #? a subset of the plant/scene. This will be especially usefull when we have different
    #? kind of geometries at different scales of representation.
end

# Case where the color is a colorant (e.g. `:red`, or `RGB(0.1,0.5,0.1)`):
function plot_opf(colorant::Observables.Observable{T}, plot) where {T<:Colorant}
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")

    traverse!(plot[:object][]; filter_fun=node -> node[:geometry] !== nothing) do node
        # get the color based on a colorscheme and the normalized attribute value
        node[color_attr_name] = Makie.lift(x -> x, colorant)

        viz!(
            plot,
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
            facetcolor=plot[:facetcolor],
            showfacets=plot[:showfacets],
        )
    end
end

# Case where the color is a color for each reference mesh:
function plot_opf(colorant::Observables.Observable{T}, plot) where {T<:Union{RefMeshColorant,DictRefMeshColorant,DictVertexRefMeshColorant}}
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")

    opf = plot[:object]

    ref_meshes = get_ref_meshes(opf[])
    # Make the plot, case where the color is a color for each reference mesh:
    traverse!(opf[]; filter_fun=node -> node[:geometry] !== nothing) do node
        node[color_attr_name] = Makie.@lift color_from_refmeshes($colorant, node, ref_meshes)
        viz!(
            plot,
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
            facetcolor=plot[:facetcolor],
            showfacets=plot[:showfacets],
        )
    end
end

function color_from_refmeshes(color::Union{RefMeshColorant,DictRefMeshColorant,DictVertexRefMeshColorant}, node, ref_meshes)
    color.colors[get_ref_mesh_index!(node, ref_meshes)]
end

# Case where the color is an attribute of the MTG:
function plot_opf(colorant::Observables.Observable{AttributeColorant}, plot)
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")
    opf = plot[:object]
    colorscheme_ = plot[:colorscheme]
    colorscheme = Makie.@lift get_colormap($colorscheme_)

    # Because we extend the `Viz` type, we cannot use the standard way of getting the attribute
    # from the plot. Instead, we need to check here if the argument is given, and give the default
    # value if not.
    # Note: If we defined our own e.g. `PlantViz` type, we could have defined a `color_missing` and 
    # `color_range` fields in it directly.

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
    if hasproperty(plot, :color_range)
        color_range = plot[:color_range]
    else
        # Get the attribute values without nothing values:    
        color_range = Makie.@lift attribute_range($opf, $colorant)
    end

    if hasproperty(plot, :index)
        hasproperty(plot, :color_vertex) && error("The `index` argument can only be used when the colors are given for each mesh, not each vertex.")
        index = plot[:index]
    else
        # The plotting index is always nothing it the colors are given for each vertex
        # in the meshes. Otherwise, it is always the first index:
        index = Makie.lift(x -> x ? nothing : 1, color_vertex)
    end

    # Make the plot, case where the color is a color for each reference mesh:
    traverse!(opf[]; filter_fun=node -> node[:geometry] !== nothing) do node
        color_attribute = Makie.@lift attr_colorant_name($colorant) # the attribute name used for coloring

        if node[color_attribute[]] === nothing
            node[color_attr_name] = color_missing
        else
            # get the color based on a colorscheme and the normalized attribute value
            node[color_attr_name] = Makie.@lift get_color(node[$color_attribute], $color_range, $index; colormap=$colorscheme)
        end

        viz!(
            plot,
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
            facetcolor=plot[:facetcolor],
            showfacets=plot[:showfacets],
            colorscheme=colorscheme,
        )
    end
end

