const _SCENE_LENGTH_DIMENSION = Unitful.dimension(1.0u"m")

"""
    SceneUnits(; length=u"m")

Units attached to a PlantGeom scene.

Scene coordinates remain plain numbers for geometry-kernel performance. The
`length` unit documents how those numbers must be interpreted, and its square
is the unit of numeric surface-area summaries. Only physical length units are
accepted.
"""
struct SceneUnits
    length::Unitful.Units

    function SceneUnits(length::Unitful.Units)
        Unitful.dimension(1.0 * length) == _SCENE_LENGTH_DIMENSION || throw(
            ArgumentError("`length` must be a physical length unit, got $length."),
        )
        return new(length)
    end
end

function SceneUnits(; length=u"m")
    length isa Unitful.Units || throw(ArgumentError(
        "`length` must be a Unitful unit such as `u\"m\"` or `u\"cm\"`, " *
        "got $(typeof(length)).",
    ))
    return SceneUnits(length)
end

"""
    scene_length_unit(scene_or_units)

Return the unit used to interpret numeric scene coordinates.
"""
scene_length_unit(units::SceneUnits) = units.length

"""
    scene_area_unit(scene_or_units)

Return the unit used to interpret numeric surface areas in a scene.
"""
scene_area_unit(units::SceneUnits) = units.length^2

function _coerce_scene_length_unit(unit, argument_name::AbstractString)
    unit isa Unitful.Units || throw(ArgumentError(
        "`$argument_name` must be a Unitful unit such as `u\"m\"` or `u\"cm\"`, " *
        "got $(typeof(unit)).",
    ))
    Unitful.dimension(1.0 * unit) == _SCENE_LENGTH_DIMENSION || throw(
        ArgumentError("`$argument_name` must be a physical length unit, got $unit."),
    )
    return unit
end

@inline function _scene_length_conversion_factor(
    geometry_length_unit,
    scene_units::SceneUnits,
)
    geometry_length_unit === nothing && return 1.0
    source_unit = _coerce_scene_length_unit(
        geometry_length_unit,
        "geometry_length_unit",
    )
    source_unit == scene_units.length && return 1.0
    return Float64(Unitful.ustrip(scene_units.length, 1.0 * source_unit))
end
