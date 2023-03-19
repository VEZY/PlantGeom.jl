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
    get_color(var <: AbstractArray, range_var, colormap=colorschemes[:viridis])
    get_color(var, range_var, colormap=colorschemes[:viridis])

Map value(s) to colors from a colormap based on a range of values
"""
function get_color(var::T, range_var; colormap=colorschemes[:viridis]) where {T<:AbstractArray}
    x2 = (range_var[2] - range_var[1])
    # get the color based on a colormap and the normalized attribute value
    [get(colormap, (i - range_var[1]) / x2) for i in var]
end

function get_color(var, range_var; colormap=colorschemes[:viridis])
    # get the color based on a colormap and the normalized attribute value
    get(colormap, (var - range_var[1]) / (range_var[2] - range_var[1]))
end
