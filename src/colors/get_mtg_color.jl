struct RefMeshColorant end

struct AttributeColorant
    color::Symbol
end

struct DictRefMeshColorant
    colors::Dict{String,Colorant}
end

struct DictVertexRefMeshColorant
    colors::Dict{String,Vector{<:Colorant}}
end

struct VectorColorant
    colors::Vector{Colorant}
end

struct VectorSymbol
    colors::Vector{Symbol}
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
# The function above is the one called by users, the ones below are the ones that search for the trait of the color (Holy trait pattern).

# This is the default implementation to catch errors:
function get_mtg_color(::Type{T}, color, opf) where {T}
    error("The type used to define the color ($T) is not supported: $color")
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

function get_mtg_color(::Type{T}, color, opf) where {T<:Colorant}
    return color
end

function get_mtg_color(::Type{DictRefMeshColorantType}, color, opf)
    # Parsing the colors in the dictionary into Colorants:
    new_color = Dict{String,Colorant}([k => parse(Colorant, v) for (k, v) in color])
    return DictRefMeshColorant(new_color)
end

function get_mtg_color(::Type{DictVertexRefMeshColorantType}, color, opf)
    # User gave at least one color as a vector, so we need to make sure we get all as vectors too:
    ref_meshes = get_ref_meshes(opf)
    new_color = Dict{String,Vector{Colorant}}()
    for (k, v) in color
        ref_mesh = ref_meshes[findfirst(x -> x.name == k, ref_meshes)]
        n_verts = Meshes.nvertices(ref_mesh)
        if v isa AbstractVector
            @assert length(v) == n_verts "The length of the color vector for refmesh $k does not match the number of vertices of that refmesh ($(length(v)) != $n_verts)"
            col = v isa AbstractVector{Colorant} ? v : parse.(Colorant, v)
        else
            col = v isa Colorant ? v : parse(Colorant, v)
            col = fill(col, n_verts)
        end
        push!(new_color, k => col)
    end
    return DictVertexRefMeshColorant(new_color)
end

function get_mtg_color(::Type{VectorColorantType}, color, opf)
    return VectorColorant(color)
end

function get_mtg_color(::Type{VectorSymbolType}, color, opf)
    return VectorSymbol(color)
end
