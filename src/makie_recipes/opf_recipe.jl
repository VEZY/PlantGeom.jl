plottype(::MultiScaleTreeGraph.Node) = Viz{<:Tuple{MultiScaleTreeGraph.Node}}

"""
using MultiScaleTreeGraph, PlantGeom, WGLMakie

# file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")
opf = read_opf(file)
ref_meshes = get_ref_meshes(opf)
transform!(opf, (node -> refmesh_to_mesh(node, ref_meshes)) => :mesh)

viz(opf)

# With one shared color:
viz(meshes, color = :green)
# One color per reference mesh:
viz(meshes, color = Dict(0 => :burlywood4, 1 => :springgreen4, 2 => :burlywood4))
# Or just changing the color of some:
viz(meshes, color = Dict(0 => :burlywood4, 2 => :burlywood4))
# One color for each vertex of the refmesh 0:
nvertices(meshes)[1]
viz(meshes, color = Dict(0 => 1:nvertices(meshes)[0]))
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
            attr_color = true
            @warn "Coloring by attribute is not implemented yet"

            # The following code falls back to the default behavior for now, delete it when
            # ready to implement the new feature:
            attr_color = false
            color = get_ref_meshes_color(ref_meshes)
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
            );
            # scale = scale,
            # symbol = symbol,
            # link = link,
            filter_fun = node -> node[:mesh] !== nothing
        )
        #? NB: implement scale / symbol / link / filter_fun filtering to be able to plot only
        #? a subset of the plant/scene. This will be especially usefull when we have different
        #? kind of geometries at different scales of representation.
    else
        nothing
    end
end
