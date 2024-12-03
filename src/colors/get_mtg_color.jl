struct RefMeshColorant end

struct AttributeColorant
    color::Symbol
end

struct DictRefMeshColorant
    colors::Dict{String,Colorant}
end

struct DictVertexRefMeshColorant
    colors::Dict{String,Union{Colorant,Vector{<:Colorant}}}
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
get_mtg_color(Dict(1 => :burlywood4, 2 => :springgreen4), opf)
```
"""
function get_mtg_color(color, opf)
    get_mtg_color(color_type(color, opf), color, opf)
end

function get_mtg_color(::Type{RefMeshColorantType}, color, opf)
    return RefMeshColorant()
end

function get_mtg_color(::Type{AttributeColorantType}, color, opf)
    return AttributeColorant(color)
end

function get_mtg_color(::Type{T}, color, opf) where {T<:Symbol}
    return parse(Colorant, color)
end

function get_mtg_color(::Type{DictRefMeshColorantType}, color, opf)
    # Parsing the colors in the dictionary into Colorants:
    new_color = Dict{String,Colorant}([k => parse(Colorant, v) for (k, v) in color])
    return DictRefMeshColorant(new_color)
end

function get_mtg_color(::Type{DictVertexRefMeshColorantType}, color, opf)
    return DictVertexRefMeshColorant(color)
end


function get_mtg_color(::Type{VectorColorantType}, color, opf)
    return VectorColorant(color)
end
