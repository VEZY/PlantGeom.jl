plottype(::MultiScaleTreeGraph.Node) = Viz{<:Tuple{MultiScaleTreeGraph.Node}}

"""
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
"""
function plot!(plot::Viz{<:Tuple{MultiScaleTreeGraph.Node}})
    # Mesh list:
    opf = plot[:object][]

    # Plot options:
    color = plot[:color][]

    ref_meshes = get_ref_meshes(opf)

    # use the color from the reference mesh if the default is used, else use the user-input color
    if isa(color, Symbol) || typeof(color) <: Colorant
        if color == :slategray3
            # Overides the default color given by MeshViz (:slategray3) with value in the ref meshes
            # see here for default value in MeshViz:
            # https://github.com/JuliaGeometry/MeshViz.jl/blob/6e37908c78c06212f09229e3e8d92483535ffa16/src/MeshViz.jl#L50
            attr_color = false
            color = get_ref_meshes_color(ref_meshes)
        elseif color in names(opf)
            # Coloring using opf attribute:
            attr_color = true
            color_attr = descendants(opf, color, ignore_nothing = true)
            key_cache = MultiScaleTreeGraph.cache_name(color)

            if length(color_attr[1]) == 1
                max_val = maximum(color_attr)
            else
                max_val = maximum(maximum.(color_attr))
            end

            transform!(opf, color => (x -> get(rainbow, x / max_val)) => key_cache, ignore_nothing = true)
        else
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

    # If not coloring by attribute color, color should have the same length as number of RefMeshes
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
        traverse!(
            opf,
            node -> viz!(
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
        traverse!(
            opf,
            function (node)
                viz!(
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
end
