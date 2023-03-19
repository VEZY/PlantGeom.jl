struct RefMeshColorant
    colors::Vector{Colorant}
end

struct AttributeColorant
    color::Symbol
end

struct DictRefMeshColorant
    colors::Dict{Int64,Colorant}
end

struct DictVertexRefMeshColorant
    colors::Dict{Int64,Union{Colorant,Vector{<:Colorant}}}
end

struct VectorColorant
    colors::Vector{Colorant}
end

"""
    get_mtg_color(color, opf)

Return the color to be used for the plot.

# Arguments

- `color`: The color to be checked.
- `opf`: The MTG to be plotted.

# Returns

The color to be used for the plot.

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom, Colors
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
opf = read_opf(file)

get_mtg_color(:red, opf)
get_mtg_color(RGB(0.1,0.5,0.1), opf)
get_mtg_color(:Length, opf)
get_mtg_color(:slategray3, opf)
get_mtg_color(Dict(1=>RGB(0.1,0.5,0.1), 2=>RGB(0.1,0.1,0.5)), opf)
```
"""
function get_mtg_color(color, opf)
    get_mtg_color(color_type(color, opf), color, opf)
end

function get_mtg_color(::Type{RefMeshColorantType}, color, opf)
    return RefMeshColorant(get_ref_meshes_color(get_ref_meshes(opf)))
end

function get_mtg_color(::Type{AttributeColorantType}, color, opf)
    return AttributeColorant(color)
end

function get_mtg_color(::Type{T}, color, opf) where {T<:Symbol}
    return parse(Colorant, color)
end

function get_mtg_color(::Type{DictRefMeshColorantType}, color, opf)
    ref_meshes = get_ref_meshes(opf)

    # If color is a dictionary, it should have the same length as number of RefMeshes, or
    # if not, we provide the missing values from the reference mesh color:
    if length(color) != length(ref_meshes.meshes)
        # Parsing the colors in the dictionary into Colorants:
        new_color = Dict{Int,Colorant}([k => parse(Colorant, v) for (k, v) in color])
        ref_cols = get_ref_meshes_color(ref_meshes)
        missing_mesh_input = setdiff(collect(keys(ref_cols)), collect(keys(color)))
        for i in missing_mesh_input
            push!(new_color, i => ref_cols[i])
        end
        color = new_color
    end

    return DictRefMeshColorant(color)
end

function get_mtg_color(::Type{DictVertexRefMeshColorantType}, color, opf)
    ref_meshes = get_ref_meshes(opf)

    # If color is a dictionary, it should have the same length as number of RefMeshes, or
    # if not, we provide the missing values from the reference mesh color:
    if length(color) != length(ref_meshes.meshes)
        # Parsing the colors in the dictionary into Colorants:
        new_color = Dict{Int,Union{Colorant,Vector{<:Colorant}}}(
            [k => (isa(v, AbstractVector) ? parse.(Colorant, v) : parse(Colorant, v)) for (k, v) in color]
        )
        ref_cols = get_ref_meshes_color(ref_meshes)
        missing_mesh_input = setdiff(collect(keys(ref_cols)), collect(keys(color)))
        for i in missing_mesh_input
            push!(new_color, i => ref_cols[i])
        end
        color = new_color
    end

    return DictVertexRefMeshColorant(color)
end


function get_mtg_color(::Type{VectorColorantType}, color, opf)
    return VectorColorant(color)
end
