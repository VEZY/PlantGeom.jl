Makie.plottype(::RefMeshes) = Viz{<:Tuple{RefMeshes}}

# Documentation is in opf_recipe.jl
function Makie.plot!(plot::Viz{<:Tuple{RefMeshes}})
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
    colorscheme = plot[:colorscheme][]

    for (key, value) in enumerate(p)
        viz!(plot, value, color=color[key], facetcolor=facetcolor, showfacets=showfacets, colorscheme=colorscheme)
    end
end
