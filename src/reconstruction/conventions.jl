struct AngleConvention
    names::Vector{Symbol}
    axis::Symbol
    frame::Symbol
    unit::Symbol
    pivot
end

struct GeometryConvention
    scale_map::Dict{Symbol,Vector{Symbol}}
    angle_map::Vector{AngleConvention}
    translation_map::Dict{Symbol,Vector{Symbol}}
    length_axis::Symbol
end

@inline _as_symbol(x::Symbol) = x
@inline _as_symbol(x::AbstractString) = Symbol(x)

function _normalize_aliases(names)
    [_as_symbol(n) for n in names]
end

function _field_or_key(x, name::Symbol, default)
    if x isa AbstractDict || x isa NamedTuple
        return haskey(x, name) ? x[name] : default
    end
    return hasproperty(x, name) ? getproperty(x, name) : default
end

function _normalize_scale_map(scale_map)
    out = Dict{Symbol,Vector{Symbol}}()
    for key in (:length, :width, :thickness)
        if haskey(scale_map, key)
            out[key] = _normalize_aliases(scale_map[key])
        else
            out[key] = Symbol[]
        end
    end
    out
end

function _normalize_translation_map(translation_map)
    out = Dict{Symbol,Vector{Symbol}}()
    for key in (:x, :y, :z)
        if haskey(translation_map, key)
            out[key] = _normalize_aliases(translation_map[key])
        else
            out[key] = Symbol[]
        end
    end
    out
end

function _normalize_angle(a)
    if a isa AngleConvention
        return a
    end

    names = _field_or_key(a, :names, nothing)
    names === nothing && error("Angle mapping requires a `names` field.")

    axis = _field_or_key(a, :axis, nothing)
    axis === nothing && error("Angle mapping requires an `axis` field.")

    frame = _field_or_key(a, :frame, :local)
    unit = _field_or_key(a, :unit, :deg)
    pivot = _field_or_key(a, :pivot, :origin)

    axis_sym = _as_symbol(axis)
    axis_sym in (:x, :y, :z) || error("Invalid angle axis '$axis_sym'. Expected :x, :y or :z.")

    frame_sym = _as_symbol(frame)
    frame_sym in (:local, :global) || error("Invalid angle frame '$frame_sym'. Expected :local or :global.")

    unit_sym = _as_symbol(unit)
    unit_sym in (:deg, :rad) || error("Invalid angle unit '$unit_sym'. Expected :deg or :rad.")

    AngleConvention(_normalize_aliases(names), axis_sym, frame_sym, unit_sym, pivot)
end

function GeometryConvention(; scale_map, angle_map, translation_map, length_axis::Symbol=:z)
    length_axis in (:x, :y, :z) || error("Invalid length axis '$length_axis'. Expected :x, :y or :z.")

    GeometryConvention(
        _normalize_scale_map(scale_map),
        [_normalize_angle(a) for a in angle_map],
        _normalize_translation_map(translation_map),
        length_axis,
    )
end

function default_geometry_convention(; angle_unit::Symbol=:deg, length_axis::Symbol=:z)
    angle_unit in (:deg, :rad) || error("Invalid angle unit '$angle_unit'. Expected :deg or :rad.")

    GeometryConvention(
        scale_map=Dict(
            :length => [:Length, :length, :L, :l],
            :width => [:Width, :width, :W, :w],
            :thickness => [:Thickness, :thickness, :Depth, :depth],
        ),
        angle_map=[
            (names=[:XEuler, :x_euler, :xeuler], axis=:x, frame=:local, unit=angle_unit, pivot=:origin),
            (names=[:YEuler, :y_euler, :yeuler], axis=:y, frame=:local, unit=angle_unit, pivot=:origin),
            (names=[:ZEuler, :z_euler, :zeuler], axis=:z, frame=:local, unit=angle_unit, pivot=:origin),
        ],
        translation_map=Dict(
            :x => [:XX, :xx],
            :y => [:YY, :yy],
            :z => [:ZZ, :zz],
        ),
        length_axis=length_axis,
    )
end

function _try_attr(node, name::Symbol)
    try
        if haskey(node, name)
            return node[name], true
        end
    catch
    end

    if node isa AbstractDict
        str_name = String(name)
        if haskey(node, str_name)
            return node[str_name], true
        end
    end

    try
        if hasproperty(node, name)
            return getproperty(node, name), true
        end
    catch
    end

    return nothing, false
end

function _as_float(x)
    x === nothing && return nothing
    x === missing && return nothing

    if x isa Unitful.AbstractQuantity
        return Float64(Unitful.ustrip(x))
    elseif x isa Real
        return Float64(x)
    elseif x isa AbstractString
        y = try
            parse(Float64, x)
        catch
            nothing
        end
        return y
    end

    return nothing
end

function _resolve_alias(node, aliases::Vector{Symbol})
    for name in aliases
        raw, present = _try_attr(node, name)
        present || continue
        return _as_float(raw), name
    end
    return nothing, nothing
end

function _resolve_value(node, aliases::Vector{Symbol}, label::Symbol; default=0.0, warn_missing=false)
    value, found = _resolve_alias(node, aliases)
    if found === nothing
        warn_missing && @warn "No mapped value found for '$label'. Using default $default." aliases=aliases
        return Float64(default)
    end
    if value === nothing
        warn_missing && @warn "Mapped value for '$label' is not numeric. Using default $default." attr=found
        return Float64(default)
    end
    return value
end

function _rotation_linear_map(axis::Symbol, angle_rad::Float64)
    axis == :x && return LinearMap(RotMatrix(AngleAxis(angle_rad, 1.0, 0.0, 0.0)))
    axis == :y && return LinearMap(RotMatrix(AngleAxis(angle_rad, 0.0, 1.0, 0.0)))
    axis == :z && return LinearMap(RotMatrix(AngleAxis(angle_rad, 0.0, 0.0, 1.0)))
    error("Invalid rotation axis '$axis'.")
end

function _pivot_from_attributes(pivot, node; warn_missing=false)
    if pivot === :origin
        return SVector{3,Float64}(0.0, 0.0, 0.0)
    elseif pivot isa Tuple && length(pivot) == 3
        if all(x -> x isa Symbol || x isa AbstractString, pivot)
            aliases = [_as_symbol(x) for x in pivot]
            vx = _resolve_value(node, [aliases[1]], :pivot_x; default=0.0, warn_missing=warn_missing)
            vy = _resolve_value(node, [aliases[2]], :pivot_y; default=0.0, warn_missing=warn_missing)
            vz = _resolve_value(node, [aliases[3]], :pivot_z; default=0.0, warn_missing=warn_missing)
            return SVector{3,Float64}(vx, vy, vz)
        end

        vals = map(_as_float, pivot)
        if all(v -> !isnothing(v), vals)
            return SVector{3,Float64}(vals[1], vals[2], vals[3])
        end
    end

    warn_missing && @warn "Invalid pivot '$pivot'. Falling back to :origin."
    return SVector{3,Float64}(0.0, 0.0, 0.0)
end

function _scale_components(length_axis::Symbol, length::Float64, width::Float64, thickness::Float64)
    transverse_1 = width
    transverse_2 = thickness

    if length_axis == :x
        return length, transverse_1, transverse_2
    elseif length_axis == :y
        return transverse_1, length, transverse_2
    else
        return transverse_1, transverse_2, length
    end
end

"""
    transformation_from_attributes(node; convention=default_geometry_convention(), warn_missing=false)

Build a `CoordinateTransformations.Transformation` from node attributes using a
`GeometryConvention`.
"""
function transformation_from_attributes(node; convention=default_geometry_convention(), warn_missing=false)
    t = IdentityTransformation()

    length_val = _resolve_value(node, convention.scale_map[:length], :length; default=1.0, warn_missing=warn_missing)
    width_val = _resolve_value(node, convention.scale_map[:width], :width; default=1.0, warn_missing=warn_missing)
    thickness_val = _resolve_value(node, convention.scale_map[:thickness], :thickness; default=width_val, warn_missing=warn_missing)

    sx, sy, sz = _scale_components(convention.length_axis, length_val, width_val, thickness_val)
    if !(sx == 1.0 && sy == 1.0 && sz == 1.0)
        t = t ∘ LinearMap(Diagonal(SVector(sx, sy, sz)))
    end

    for angle in convention.angle_map
        value, found = _resolve_alias(node, angle.names)
        if found === nothing
            warn_missing && @warn "No mapped value found for angle. Skipping." axis=angle.axis aliases=angle.names
            continue
        elseif value === nothing
            warn_missing && @warn "Mapped angle value is not numeric. Skipping." attr=found axis=angle.axis
            continue
        end

        angle_rad = angle.unit == :deg ? deg2rad(value) : value
        rot = _rotation_linear_map(angle.axis, angle_rad)

        if angle.frame == :local
            t = t ∘ rot
        else
            pivot = _pivot_from_attributes(angle.pivot, node; warn_missing=warn_missing)
            t = recenter(rot, pivot) ∘ t
        end
    end

    tx = _resolve_value(node, convention.translation_map[:x], :x; default=0.0, warn_missing=warn_missing)
    ty = _resolve_value(node, convention.translation_map[:y], :y; default=0.0, warn_missing=warn_missing)
    tz = _resolve_value(node, convention.translation_map[:z], :z; default=0.0, warn_missing=warn_missing)

    if tx != 0.0 || ty != 0.0 || tz != 0.0
        t = Translation(tx, ty, tz) ∘ t
    end

    t
end

"""
    geometry_from_attributes(node, ref_mesh; convention=default_geometry_convention(), dUp=1.0, dDwn=1.0, warn_missing=false)

Create a `Geometry` from node attributes and a reference mesh.
"""
function geometry_from_attributes(node, ref_mesh;
    convention=default_geometry_convention(),
    dUp=1.0,
    dDwn=1.0,
    warn_missing=false,
)
    transformation = transformation_from_attributes(node; convention=convention, warn_missing=warn_missing)
    Geometry(ref_mesh=ref_mesh, transformation=transformation, dUp=dUp, dDwn=dDwn)
end

"""
    set_geometry_from_attributes!(node, ref_mesh; convention=default_geometry_convention(), dUp=1.0, dDwn=1.0, warn_missing=false)

Compute and assign `node[:geometry]` from attribute conventions.
"""
function set_geometry_from_attributes!(node, ref_mesh;
    convention=default_geometry_convention(),
    dUp=1.0,
    dDwn=1.0,
    warn_missing=false,
)
    node[:geometry] = geometry_from_attributes(
        node,
        ref_mesh;
        convention=convention,
        dUp=dUp,
        dDwn=dDwn,
        warn_missing=warn_missing,
    )
    node
end
