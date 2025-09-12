# The user can pass the color either as a colorant, a symbol, a dictionary, or a vector.
# If the user passes a colorant, then we color everything by that color, and we don'T
# need a colorbar. 
# If the user passes a symbol, then it is either an attribute of the MTG or a colorant (e.g. :red).
# If it is an attribute, then we color by that attribute, and we need a colorbar.
# If it is a colorant, then we color everything by that color, and we don't need a colorbar.
# If the user passes a dictionary, then we assume that it maps the reference mesh to a colorant.
# We color by the color of the reference mesh, and we don't need a colorbar.
# If the user passes a vector, then we assume that it is a vector of colorants, one for each
# node in the MTG. Here we need a colorbar.

struct RefMeshColorantType end
struct AttributeColorantType end
struct DictRefMeshColorantType end
struct DictVertexRefMeshColorantType end
struct VectorColorantType end
struct VectorSymbolType end

color_type(color::T, opf) where {T<:Colorant} = T

"""
    color_type(color, opf)

Return the type of the color, whether it is an attribute, a colorant, or a RefMeshColorant.

# Arguments

- `color`: The color to be checked.
- `opf`: The MTG to be plotted.

# Returns

- `RefMeshColorant`: If the color is :slategray3, then it is the default color given by Meshes,
so we assume nothing was passed by the user and color by reference mesh instead.
- `AttributeColorant`: If the color is an attribute of the MTG, then we color by that attribute.
- `T`: If the color is a colorant, then we color everything by that color.

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom, Colors

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")

opf = read_opf(file)

# Colors:
color_type(:red, opf)
color_type(RGB(0.1,0.5,0.1), opf)

# Attributes:
color_type(:Length, opf)

# Default color:
color_type(:slategray3, opf)

# Dict of colors:
color_type(Dict(1=>RGB(0.1,0.5,0.1), 2=>RGB(0.5,0.1,0.1)), opf)
```
"""
function color_type(color::T, opf) where {T<:Symbol}
    # If the color is :slategray3, then it is the default color given by Meshes,
    # so we assume nothing was passed by the user and color by reference mesh instead.
    if color == :slategray3
        return RefMeshColorantType
    elseif color in get_attributes(opf)
        return AttributeColorantType
    else
        # Try parsing the symbol into a color, if we can't, that means that the user probably wants and attribute that does not exist.
        try
            parse(Colorant, color)
        catch e
            error("The symbol used to define the color ($color) is not a color nor an attribute of the MTG. See `get_attributes` to list the attributes.")
        end

        return T
    end
end

function color_type(color::T, opf) where {T<:AbstractDict}
    if any([isa(v, AbstractVector) for (k, v) in color])
        # Colors are given for vertices, not for the entire mesh
        return DictVertexRefMeshColorantType
    else
        return DictRefMeshColorantType
    end
end

function color_type(color::T, opf) where {T<:AbstractVector{<:Colorant}}
    return VectorColorantType
end

function color_type(color::T, opf) where {T<:AbstractVector{<:Symbol}}
    return VectorSymbolType
end

function color_type(color::T, opf) where {T<:AbstractVector}
    error("The type of the color vector is not supported: $T. Please use a vector of Colorants or Symbols instead.")
end

need_colorbar(color, opf) = false
need_colorbar(color::AttributeColorantType, opf) = true
need_colorbar(color::VectorColorantType, opf) = true
need_colorbar(color::VectorSymbolType, opf) = true