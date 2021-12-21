plottype(::RefMeshes) = Viz{<:Tuple{RefMeshes}}

"""
using MultiScaleTreeGraph, PlantGeom, WGLMakie, Meshes

file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)

viz(meshes)
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
function plot!(plot::Viz{<:Tuple{RefMeshes}})
    # Mesh list:
    p = align_ref_meshes(plot[:object][])

    n_meshes = length(p)

    # Plot options:
    color = plot[:color][]

    # use the color from the reference mesh if the default is used, else use the user-input color
    if isa(color, Symbol) || typeof(color) <: Colorant
        if color == :slategray3
            # Overides the default color given by MeshViz (:slategray3) with value in the ref meshes
            # see here for default value in MeshViz:
            # https://github.com/JuliaGeometry/MeshViz.jl/blob/6e37908c78c06212f09229e3e8d92483535ffa16/src/MeshViz.jl#L50
            color = get_ref_meshes_color(plot[:object][])
        else
            color = Dict(zip(keys(p), repeat([color], n_meshes)))
        end
    elseif !isa(color, Dict)
        error(
            "color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "Dict{Int,T} such as Dict(0 => :green) or Dict(0 => [colors...])"
        )
    end

    if length(color) != n_meshes
        new_color = Dict{Int,Any}(color)
        ref_cols = get_ref_meshes_color(plot[:object][])
        missing_mesh_input = setdiff(collect(keys(ref_cols)), collect(keys(color)))
        for i in missing_mesh_input
            push!(new_color, i => ref_cols[i])
        end
        color = new_color
    end

    facetcolor = plot[:facetcolor][]
    showfacets = plot[:showfacets][]
    colormap = plot[:colormap][]

    for (key, value) in p
        viz!(plot, value, color = color[key], facetcolor = facetcolor, showfacets = showfacets, colormap = colormap)
    end
end
