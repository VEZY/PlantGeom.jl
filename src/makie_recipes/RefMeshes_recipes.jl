plottype(::RefMeshes) = Viz{<:Tuple{RefMeshes}}

"""
    viz!(ref_meshes; kwargs...)

Plot all reference meshes in a single 3d plot using Makie.

# Examples

```julia
using PlantGeom, GLMakie

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
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
# Colors as a vector (no missing values allowed here):
viz(meshes, color = [:burlywood4, :springgreen4, :burlywood4])
```
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
    elseif length(color) != n_meshes && !isa(color, Dict)
        error(
            "color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "a vector of colors, or Dict{Int,T} such as Dict(1 => :green) or ",
            "Dict(2 => [colors...])"
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

    for (key, value) in enumerate(p)
        viz!(plot, value, color = color[key], facetcolor = facetcolor, showfacets = showfacets, colormap = colormap)
    end
end
