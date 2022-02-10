function get_colormap(colormap)
    if typeof(colormap) <: ColorScheme
        return colormap
    elseif typeof(colormap) <: Symbol
        return colorschemes[colormap]
    else
        error("colormap must be a ColorScheme")
    end
end
