Makie.args_preferred_axis(::Union{T,Vector{T}}) where {T<:RefMesh} = Makie.LScene

function Makie.plot!(plot::PlantViz{<:Tuple{Union{T,Vector{T}}}}) where {T<:RefMesh}
    plot_refmesh(plot, :mtg)
end

function plot_refmesh(plot, mtg_name=:mtg)
    Makie.map!(plot.attributes, [:colormap], :colormap_resolved) do cm
        get_colormap(cm)
    end

    Makie.map!(plot.attributes, [mtg_name, :color], [:reference_meshes, :colorant]) do opf, c
        p = PlantGeom.align_ref_meshes(opf)
        ref_meshes_keys = keys(p)
        refmesh_vector = [p[k] for k in ref_meshes_keys]
        n_meshes = length(p)

        # use the color from the reference mesh if the default is used, else use the user-input color
        if c == :slategray3 #isnothing(c)
            colorant = get_ref_meshes_color(opf)
        elseif isa(c, Symbol) || typeof(c) <: Colorant
            colorant = Dict(zip(keys(p), repeat([c], n_meshes)))
        elseif length(c) != n_meshes && !isa(c, Dict)
            error(
                "color argument should be of type Colorant ",
                "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
                "a vector of colors, or Dict{Int,T} such as Dict(1 => :green) or ",
                "Dict(2 => [colors...])"
            )
        else
            colorant = c
        end

        # Parsing the colors in the dictionary into Colorants:
        colorant_dict = Dict{String,Union{Colorant,Vector{<:Colorant}}}([k => isa(v, AbstractArray) ? parse.(Colorant, v) : fill(parse(Colorant, v), Meshes.nvertices(p[k])) for (k, v) in colorant])

        if length(colorant) != n_meshes
            ref_cols = get_ref_meshes_color(opf)
            missing_mesh_input = setdiff(collect(keys(ref_cols)), collect(keys(colorant)))
            for i in missing_mesh_input
                push!(colorant_dict, i => fill(ref_cols[i], Meshes.nvertices(p[i])))
            end
        end

        colorant_vector = vcat([colorant_dict[k] for k in ref_meshes_keys]...)

        return refmesh_vector, colorant_vector
    end

    # Merge the meshes:
    Makie.map!(plot.attributes, :reference_meshes, [:vertices, :faces]) do meshes
        return meshes_to_makie(merge_simple_meshes(meshes))
    end

    Makie.mesh!(plot, Makie.Attributes(plot), plot[:vertices], plot[:faces], color=plot[:colorant], colormap=plot[:colormap_resolved])

    return plot
end
