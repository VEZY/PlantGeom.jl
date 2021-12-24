plottype(::MultiScaleTreeGraph.Node) = Viz{<:Tuple{MultiScaleTreeGraph.Node}}

"""
using MultiScaleTreeGraph, PlantGeom, GLMakie

# file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")
# file = "D:/OneDrive - cirad.fr/Travail_AMAP/Processes/Light_interception_GPU/Julia_3D/P6_Ru_ii_L2P02.opf"
opf = read_opf(file)
ref_meshes = get_ref_meshes(opf)
# viz(ref_meshes)
transform!(opf, (node -> refmesh_to_mesh(node, ref_meshes)) => :mesh)

# With one shared color:
viz(opf, color = :green)
# One color per reference mesh:
viz(opf, color = Dict(0 => :burlywood4, 1 => :springgreen4))
# Or just changing the color of some:
viz(opf, color = Dict(0 => :burlywood4))
# One color for each vertex of the refmesh 1:
viz(opf, color = Dict(1 => 1:nvertices(ref_meshes)[1]))

# Or coloring by opf attribute, e.g. using the mesh max Z coordinates:
transform!(opf, :mesh => (x -> maximum([i.coords[3] for i in x.points])) => :z_max, ignore_nothing = true)
viz(opf, color = :z_max)

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

            transform!(opf, color => (x -> get(rainbow, x / maximum(color_attr))) => key_cache, ignore_nothing = true)
        else
            attr_color = false
            color = Dict(zip(keys(ref_meshes.meshes), repeat([color], length(ref_meshes.meshes))))
        end
    elseif !isa(color, Dict)
        error(
            "color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "Dict{Int,T} such as Dict(0 => :green) or Dict(0 => [colors...])"
        )
    else
        attr_color = false
    end

    # If not coloring by attribute color, color should have the same length as number of ReMeshes
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
                node[:mesh],
                color = color[node[:geometry][:shapeIndex]],
                facetcolor = facetcolor,
                showfacets = showfacets,
                colormap = colormap
            )
            ;
            # scale = scale,
            # symbol = symbol,
            # link = link,
            filter_fun = node -> node[:mesh] !== nothing
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
                    node[:mesh],
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
            filter_fun = node -> node[:mesh] !== nothing
        )
    end
end
