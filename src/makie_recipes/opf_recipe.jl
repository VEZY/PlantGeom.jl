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

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
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
# One color for each vertex of the refmesh 1:
viz(opf, color = Dict(1 => 1:nvertices(get_ref_meshes(opf))[1]))

# Or coloring by opf attribute, e.g. using the mesh max Z coordinates (NB: need to use
# `refmesh_to_mesh!` before, see above):
transform!(opf, :geometry => (x -> zmax(x.mesh)) => :z_max, ignore_nothing = true)
viz(opf, color = :z_max)

# Or even coloring by the value of the Z coordinates of each vertex:
transform!(opf, :geometry => (x -> [i.coords[3] for i in x.mesh.points]) => :z, ignore_nothing = true)
viz(opf, color = :z, showfacets = true)
```
"""
viz, viz!

function Makie.plot!(plot::Viz{<:Tuple{MultiScaleTreeGraph.Node}})
    # function Makie.plot!(plot::Viz{<:Tuple{MultiScaleTreeGraph.Node}}, fig::Makie.GridPosition; axis = NamedTuple(), kwargs...)

    # ax = Makie.Axis(fig[1, 2]; axis...)

    # Mesh list:
    opf = plot[:object][]

    # Plot options:
    color = plot[:color][]
    colormap = get_colormap(plot[:colormap][])
    color_missing = RGBA(0, 0, 0, 0.3)
    ref_meshes = get_ref_meshes(opf)
    colorbar = false

    # Color the meshes:
    if isa(color, Symbol) || typeof(color) <: Colorant
        if color == :slategray3
            # No color is given, we inherit from the default of MeshViz `Viz` (:slategray3) .
            # What we do in this case is use the color given by each reference mesh in the MTG
            # See here for default value in MeshViz:
            # https://github.com/JuliaGeometry/MeshViz.jl/blob/6e37908c78c06212f09229e3e8d92483535ffa16/src/MeshViz.jl#L50
            attr_color = false
            color = get_ref_meshes_color(ref_meshes)
        elseif color in get_attributes(opf)
            # The user provides the name of an attribute from the MTG, coloring using the attribute:
            attr_color = true
            colorbar = true
            # Get the attribute values without nothing values:
            range_val = attribute_range(opf, color)
            # Make a temporary name for our color to use as attribute:
            key_cache = MultiScaleTreeGraph.cache_name(color)

            # Compute the color of each mesh based on the attribute value (use color_missing
            # if no value).
            transform!(
                opf,
                color =>
                    (x -> if x === nothing
                        color_missing
                    else
                        # get the color based on a colormap and the normalized attribute value
                        get_color(colormap, x, range_val)
                    end
                    ) => key_cache
            )
        else
            # User-input single color-value. Here we give the same color to all reference meshes:
            attr_color = false
            color = Dict(zip(keys(ref_meshes.meshes), repeat([color], length(ref_meshes.meshes))))
        end
    elseif length(color) != length(ref_meshes.meshes) && !isa(color, Dict)
        error(
            "color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "an MTG attribute, or a Dict{Int,Colorant} mapping reference meshes to a color."
        )
    else
        attr_color = false
    end

    # If color is not an attribute, it should have the same length as number of RefMeshes, or
    # if not, we provide the reference mesh color:
    if attr_color == false && length(color) != length(ref_meshes.meshes)
        new_color = Dict{Int,Any}(color)
        ref_cols = get_ref_meshes_color(ref_meshes)
        missing_mesh_input = setdiff(collect(keys(ref_cols)), collect(keys(color)))
        for i in missing_mesh_input
            push!(new_color, i => ref_cols[i])
        end
        color = new_color
    end

    facetcolor = plot[:facetcolor][]
    showfacets = plot[:showfacets][]
    colormap = plot[:colormap][]

    if attr_color == false
        # Make the plot, case where the color is a color for each reference mesh:
        traverse!(
            opf,
            node -> viz!(
                # ax,
                plot,
                node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
                color = color[get_ref_mesh_index!(node, ref_meshes)],
                facetcolor = facetcolor,
                showfacets = showfacets,
                colormap = colormap
            )
            ;
            # scale = scale,
            # symbol = symbol,
            # link = link,
            filter_fun = node -> node[:geometry] !== nothing
        )
        #? NB: implement scale / symbol / link / filter_fun filtering to be able to plot only
        #? a subset of the plant/scene. This will be especially usefull when we have different
        #? kind of geometries at different scales of representation.
    else
        # Make the plot, case where the color is an attribute from the MTG:
        traverse!(
            opf,
            function (node)
                viz!(
                    # ax,
                    plot,
                    node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
                    color = node[key_cache],
                    facetcolor = facetcolor,
                    showfacets = showfacets,
                    colormap = colormap
                )
                pop!(node, key_cache) # Remove the cached variable
            end;
            # scale = scale,
            # symbol = symbol,
            # link = link,
            filter_fun = node -> node[:geometry] !== nothing
        )
    end

    # if colorbar
    # cb = Makie.Colorbar(plot.parent, label = string(color), colormap = colormap, colorrange = range_val)
    # end

    # return Makie.AxisPlot(ax, plot)
end
