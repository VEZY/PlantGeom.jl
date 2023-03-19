Makie.plottype(::RefMeshes) = Viz{<:Tuple{RefMeshes}}

# Documentation is in opf_recipe.jl
function Makie.plot!(plot::Viz{<:Tuple{RefMeshes}})
    # Mesh list:
    p = align_ref_meshes(plot[:object][])

    n_meshes = length(p)

    # Plot options:
    color = plot[:color]

    # use the color from the reference mesh if the default is used, else use the user-input color
    if isa(color[], Symbol) || typeof(color[]) <: Colorant
        if color[] == :slategray3
            # Overides the default color given by MeshViz (:slategray3) with value in the ref meshes
            # see here for default value in MeshViz:
            # https://github.com/JuliaGeometry/MeshViz.jl/blob/6e37908c78c06212f09229e3e8d92483535ffa16/src/MeshViz.jl#L50
            ref_colors = get_ref_meshes_color(plot[:object][])
            colorant = Observables.Observable(Dict(zip(1:n_meshes, ref_colors)))
        else
            colorant = Makie.lift(x -> Dict(zip(keys(p), repeat([x], n_meshes))), color)
        end
    elseif length(color[]) != n_meshes && !isa(color[], Dict)
        error(
            "color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "a vector of colors, or Dict{Int,T} such as Dict(1 => :green) or ",
            "Dict(2 => [colors...])"
        )
    else
        colorant = color
    end

    # Parsing the colors in the dictionary into Colorants:
    new_color = Dict{Int,Union{Colorant,Vector{<:Colorant}}}([k => isa(v, AbstractArray) ? parse.(Colorant, v) : parse(Colorant, v) for (k, v) in colorant[]])

    if length(colorant[]) != n_meshes
        ref_cols = get_ref_meshes_color(plot[:object][])
        missing_mesh_input = setdiff(collect(keys(ref_cols)), collect(keys(colorant[])))
        for i in missing_mesh_input
            push!(new_color, i => ref_cols[i])
        end
    end

    for (key, value) in enumerate(p)
        viz!(plot, value, color=new_color[key], facetcolor=plot[:facetcolor], showfacets=plot[:showfacets], colorscheme=plot[:colorscheme])
    end
end
