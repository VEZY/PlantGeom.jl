"""
    get_colormap(colormap)

Get the colormap as a ColorScheme if it is a named color or ColorScheme
"""
function get_colormap(colormap)
    if colormap === nothing
        return colorschemes[:viridis]
    elseif typeof(colormap) <: ColorScheme
        return colormap
    elseif typeof(colormap) <: Symbol
        return colorschemes[colormap]
    else
        error("colormap must be a ColorScheme")
    end
end
"""
    get_color_range(colorrange, opf, colorant)

Get the color range from the `colorrange` argument or from the MTG attribute.

# Arguments

- `colorrange`: the color range specified by the user, can be an Observable or a tuple of two values.
- `opf`: the MTG object.
- `colorant`: the color attribute to use for the range.

# Returns

- `colorrange`: the color range as a tuple of two values.
"""
function get_color_range(colorrange::Nothing, opf, colorant::AttributeColorant)
    return PlantGeom.attribute_range(opf, colorant, ustrip=true)
end

function get_color_range(colorrange, opf, colorant::AttributeColorant)
    return Unitful.ustrip.(colorrange)
end

# If we don't color by attribute, no need to get a range
function get_color_range(colorrange, opf, colorant)
    return nothing
end
"""
    get_color(var <: AbstractArray, range_var, colormap=colorschemes[:viridis])
    get_color(var, range_var, colormap=colorschemes[:viridis])

Map value(s) to colors from a colormap based on a range of values

# Arguments

- `var`: value(s) to map to colors
- `range_var`: range of values to map to colors
- `colormap`: colormap to use

# Returns

- `color`: color(s) corresponding to `var`

# Examples

```julia
using Colors

get_color(1, 1:2, colormap = colorschemes[:viridis]) # returns RGB{N0f8}(0.267004,0.00487433,0.329415)
get_color(1:2, 1:10, colormap = colorschemes[:viridis]) # returns RGB{N0f8}(0.267004,0.00487433,0.329415)
get_color(1:2, 1:10, 1, colormap = colorschemes[:viridis]) # returns RGB{N0f8}(0.267004,0.00487433,0.329415)
"""
function get_color(var::T, range_var, index::Nothing=nothing; colormap=colorschemes[:viridis]) where {T<:AbstractArray}
    range_var = Unitful.ustrip.(range_var)
    x2 = (range_var[2] - range_var[1])
    # get the color based on a colormap and the normalized attribute value
    [get(colormap, (i - range_var[1]) / x2) for i in Unitful.ustrip.(var)]
end

function get_color(var::T, range_var, index::I; colormap=colorschemes[:viridis]) where {T<:AbstractArray,I<:Integer}
    get_color(var[index], range_var; colormap=colormap)
end

function get_color(var, range_var, index::I=1; colormap=colorschemes[:viridis]) where {I<:Integer}
    range_var = Unitful.ustrip.(range_var)
    # get the color based on a colormap and the normalized attribute value
    get(colormap, (Unitful.ustrip(var) - range_var[1]) / (range_var[2] - range_var[1]))
end

function get_color(var::T, range_var, index::I=1; colormap=colorschemes[:viridis]) where {I<:Integer,T<:Union{Symbol,Colorant}}
    var
end

function mtg_XYZ_color(mtg, color, edge_color, colormap; color_missing=RGBA(0, 0, 0, 0.3))
    if Symbol(color) in get_attributes(mtg)
        # Color is an attribute from the mtg:
        df_coordinates = mtg_coordinates_df(mtg, color, force=true)
        max_color = maximum(skipmissing(df_coordinates[:, color]))
        color_var = [i === missing ? color_missing : RGBA(get(colormap, i / max_color)) for i in df_coordinates[:, color]]
        text_color = color_var
    elseif typeof(color) <: Colorant || typeof(color) <: String || typeof(color) <: Symbol
        df_coordinates = mtg_coordinates_df(mtg, force=true)
        color_var = color
        text_color = color_var
    else
        error(
            "color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "an MTG attribute."
        )
    end

    if Symbol(edge_color) in get_attributes(mtg)
        if edge_color == color
            # If edge_color use the same attribute than color, use color_var (avoid recomputing)
            edge_color_var = [[color_var[i-1], color_var[i]] for i in 2:length(color_var)]
            pushfirst!(edge_color_var, edge_color_var[1])
        else
            # If edge_color is different than color, and is an attribute from the mtg
            df_coordinates = mtg_coordinates_df(mtg, edge_color, force=true)

            ecol = df_coordinates[:, edge_color]
            max_edge_color = maximum(skipmissing(ecol))
            edge_color_var = []
            for i in 2:size(df_coordinates, 1)
                if ecol[i-1] === missing || ecol[i] === missing
                    push!(edge_color_var, color_missing)
                else
                    push!(edge_color_var, RGBA.(get(colormap, [ecol[i-1] / max_edge_color, ecol[i] / max_edge_color])))
                end
            end
            pushfirst!(edge_color_var, edge_color_var[1])
        end
    elseif typeof(edge_color) <: Colorant || typeof(edge_color) <: String || typeof(edge_color) <: Symbol
        # edge_color is just a single color
        edge_color_var = fill([edge_color, edge_color], size(df_coordinates, 1))
    else
        error(
            "edge_color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "an MTG attribute."
        )
    end

    return df_coordinates, color_var, edge_color_var, text_color
end