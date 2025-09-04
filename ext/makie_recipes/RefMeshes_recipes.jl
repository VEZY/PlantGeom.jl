Makie.plottype(::Vector{T}) where {T<:RefMesh} = MeshesMakieExt.Viz{<:Tuple{Vector{T}}}
Makie.args_preferred_axis(::Union{T,Vector{T}}) where {T<:RefMesh} = Makie.LScene

function Makie.plot!(plot::PlantViz{<:Tuple{Union{T,Vector{T}}}}) where {T<:RefMesh}
    plot_refmesh(plot, :mtg)
end

# Documentation is in opf_recipe.jl
function Makie.plot!(plot::MeshesMakieExt.Viz{<:Tuple{Union{T,Vector{T}}}}) where {T<:RefMesh}
    @warn "The `viz` function is deprecated, use `plantviz` instead."
    plot_refmesh(plot, :object)
end

function plot_refmesh(plot, mtg_name=:mtg)
    # Mesh list:
    p = PlantGeom.align_ref_meshes(plot[mtg_name][])
    n_meshes = length(p)

    # Plot options:
    color = plot[:color]

    # use the color from the reference mesh if the default is used, else use the user-input color
    if isa(color[], Symbol) || typeof(color[]) <: Colorant
        if color[] == :slategray3
            # Overides the default color given by MeshViz (:slategray3) with value in the ref meshes
            # see here for default value in MeshViz:
            # https://github.com/JuliaGeometry/MeshViz.jl/blob/6e37908c78c06212f09229e3e8d92483535ffa16/src/MeshViz.jl#L50
            ref_colors = get_ref_meshes_color(plot[mtg_name][])
            colorant = Observables.Observable(ref_colors)
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
    new_color = Dict{String,Union{Colorant,Vector{<:Colorant}}}([k => isa(v, AbstractArray) ? parse.(Colorant, v) : parse(Colorant, v) for (k, v) in colorant[]])

    if length(colorant[]) != n_meshes
        ref_cols = get_ref_meshes_color(plot[mtg_name][])
        missing_mesh_input = setdiff(collect(keys(ref_cols)), collect(keys(colorant[])))
        for i in missing_mesh_input
            push!(new_color, i => ref_cols[i])
        end
    end

    for (name, refmesh) in p
        MeshesMakieExt.viz!(plot, refmesh, color=new_color[name], segmentcolor=plot[:segmentcolor], showsegments=plot[:showsegments], colormap=plot[:colormap])
    end
end
