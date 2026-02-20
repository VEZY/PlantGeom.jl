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

"""
    default_amap_geometry_convention(; angle_unit=:deg)

Return a `GeometryConvention` close to AMAP/OpenAlea defaults:

- organ length aligned on the local `+X` axis
- insertion angles (`XInsertionAngle`, `YInsertionAngle`, `ZInsertionAngle`)
- local Euler angles (`XEuler`, `YEuler`, `ZEuler`)
- OPF-style translations (`XX`, `YY`, `ZZ`) still supported
"""
function default_amap_geometry_convention(; angle_unit::Symbol=:deg)
    angle_unit in (:deg, :rad) || error("Invalid angle unit '$angle_unit'. Expected :deg or :rad.")

    GeometryConvention(
        scale_map=Dict(
            :length => [:Length, :length, :L, :l],
            :width => [:Width, :width, :W, :w],
            :thickness => [:Thickness, :thickness, :Depth, :depth],
        ),
        angle_map=[
            (names=[:XInsertionAngle, :x_insertion_angle, :xinsertionangle], axis=:x, frame=:local, unit=angle_unit, pivot=:origin),
            (names=[:YInsertionAngle, :y_insertion_angle, :yinsertionangle], axis=:y, frame=:local, unit=angle_unit, pivot=:origin),
            (names=[:ZInsertionAngle, :z_insertion_angle, :zinsertionangle], axis=:z, frame=:local, unit=angle_unit, pivot=:origin),
            (names=[:XEuler, :x_euler, :xeuler], axis=:x, frame=:local, unit=angle_unit, pivot=:origin),
            (names=[:YEuler, :y_euler, :yeuler], axis=:y, frame=:local, unit=angle_unit, pivot=:origin),
            (names=[:ZEuler, :z_euler, :zeuler], axis=:z, frame=:local, unit=angle_unit, pivot=:origin),
        ],
        translation_map=Dict(
            :x => [:XX, :xx],
            :y => [:YY, :yy],
            :z => [:ZZ, :zz],
        ),
        length_axis=:x,
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

const _ZERO3 = SVector{3,Float64}(0.0, 0.0, 0.0)
const _I3 = SMatrix{3,3,Float64,9}(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
const _UP3 = SVector{3,Float64}(0.0, 0.0, 1.0)

@inline _to_svec3(v) = SVector{3,Float64}(Float64(v[1]), Float64(v[2]), Float64(v[3]))

function _empty_scale_map()
    Dict(:length => Symbol[], :width => Symbol[], :thickness => Symbol[])
end

function _empty_translation_map()
    Dict(:x => Symbol[], :y => Symbol[], :z => Symbol[])
end

function _convention_without_translation(convention::GeometryConvention)
    GeometryConvention(
        scale_map=convention.scale_map,
        angle_map=convention.angle_map,
        translation_map=_empty_translation_map(),
        length_axis=convention.length_axis,
    )
end

function _convention_angles_only(convention::GeometryConvention)
    GeometryConvention(
        scale_map=_empty_scale_map(),
        angle_map=convention.angle_map,
        translation_map=_empty_translation_map(),
        length_axis=convention.length_axis,
    )
end

function _convention_scale_only(convention::GeometryConvention)
    GeometryConvention(
        scale_map=convention.scale_map,
        angle_map=AngleConvention[],
        translation_map=_empty_translation_map(),
        length_axis=convention.length_axis,
    )
end

@inline function _unit_axis(axis::Symbol)
    axis == :x && return SVector{3,Float64}(1.0, 0.0, 0.0)
    axis == :y && return SVector{3,Float64}(0.0, 1.0, 0.0)
    return SVector{3,Float64}(0.0, 0.0, 1.0)
end

@inline _frame_transform(rot::SMatrix{3,3,Float64,9}, pos::SVector{3,Float64}) = AffineMap(Matrix(rot), pos)

function _rotation_part(t)
    m = transformation_matrix4(t)
    SMatrix{3,3,Float64}(m[1:3, 1:3])
end

function _linear_part(t)
    m = transformation_matrix4(t)
    SMatrix{3,3,Float64}(m[1:3, 1:3])
end

@inline function _normalize_direction(v::SVector{3,Float64}, rot::SMatrix{3,3,Float64,9}, axis::Symbol)
    n = norm(v)
    if n > 0
        return v / n
    end
    d = rot * _unit_axis(axis)
    nd = norm(d)
    nd > 0 ? d / nd : _unit_axis(axis)
end

function _has_numeric_alias(node, aliases::Vector{Symbol})
    value, found = _resolve_alias(node, aliases)
    return found !== nothing && value !== nothing
end

function _has_explicit_translation(node, convention::GeometryConvention)
    _has_numeric_alias(node, convention.translation_map[:x]) ||
    _has_numeric_alias(node, convention.translation_map[:y]) ||
    _has_numeric_alias(node, convention.translation_map[:z])
end

function _resolve_ref_mesh(node, ref_meshes::AbstractDict)
    name = symbol(node)
    haskey(ref_meshes, name) && return ref_meshes[name]
    name_sym = Symbol(name)
    haskey(ref_meshes, name_sym) && return ref_meshes[name_sym]
    return nothing
end

function _resolve_node_convention(node, default_convention::GeometryConvention, conventions::AbstractDict)
    isempty(conventions) && return default_convention
    name = symbol(node)
    haskey(conventions, name) && return conventions[name]
    name_sym = Symbol(name)
    haskey(conventions, name_sym) && return conventions[name_sym]
    return default_convention
end

function _offset_value(node, aliases::Vector{Symbol}, default::Float64)
    value, found = _resolve_alias(node, aliases)
    if found === nothing || value === nothing
        return default
    end
    return value
end

function _resolve_text_alias(node, aliases::Vector{Symbol})
    for name in aliases
        raw, present = _try_attr(node, name)
        present || continue
        if raw isa Symbol
            return String(raw), name
        elseif raw isa AbstractString
            return String(raw), name
        end
    end
    return nothing, nothing
end

function _insertion_mode(node, aliases::Vector{Symbol})
    raw, _ = _resolve_text_alias(node, aliases)
    raw === nothing && return :BORDER

    mode = uppercase(strip(raw))
    mode == "CENTER" && return :CENTER
    mode == "BORDER" && return :BORDER
    mode == "WIDTH" && return :WIDTH
    mode == "HEIGHT" && return :HEIGHT
    return :BORDER
end

function _verticil_mode(mode::Symbol)
    mode in (:rotation360, :none) || error("Invalid verticil_mode '$mode'. Expected :rotation360 or :none.")
    return mode
end

@inline function _secondary_axis(axis::Symbol)
    axis == :x && return :y
    axis == :y && return :z
    return :x
end

@inline function _normal_axis(axis::Symbol)
    axis == :x && return :z
    axis == :y && return :x
    return :y
end

@inline function _safe_normalize(v::SVector{3,Float64}, fallback::SVector{3,Float64})
    n = norm(v)
    n > 0 ? (v / n) : fallback
end

function _project_on_plane(plane_normal::SVector{3,Float64}, vector_to_project::SVector{3,Float64})
    n_norm = norm(plane_normal)
    n_norm > 0 || return nothing
    n = plane_normal / n_norm
    scalar = dot(vector_to_project, n)

    if abs(scalar) < 1e-4
        return vector_to_project
    elseif abs(scalar) > 0.9999
        return nothing
    end

    vector_to_project - scalar * n
end

function _is_insertion_angle(angle::AngleConvention)
    any(name -> occursin("insertion", lowercase(String(name))), angle.names)
end

function _insertion_angle_aliases(convention::GeometryConvention, axis::Symbol)
    for angle in convention.angle_map
        angle.axis == axis || continue
        _is_insertion_angle(angle) || continue
        return angle.names
    end
    return Symbol[]
end

function _ramification_rank(node, parent_node)
    node_symbol = symbol(node)
    rank = 0
    total = 0
    found = false

    for child in children(parent_node)
        if link(child) == "+" && symbol(child) == node_symbol
            if child === node
                rank = total
                found = true
            end
            total += 1
        end
    end

    if total == 0
        return 0, 1
    end

    if !found
        rank = 0
    end

    return rank, total
end

function _fallback_insertion_x_angle_deg(
    node,
    parent_node,
    node_convention::GeometryConvention,
    phyllotaxy_aliases::Vector{Symbol},
    verticil_mode::Symbol,
)
    insertion_x_aliases = _insertion_angle_aliases(node_convention, :x)
    if !isempty(insertion_x_aliases) && _has_numeric_alias(node, insertion_x_aliases)
        return 0.0
    end

    extra = _offset_value(node, phyllotaxy_aliases, 0.0)

    if _verticil_mode(verticil_mode) == :rotation360
        rank, total = _ramification_rank(node, parent_node)
        extra += 360.0 * (rank / total)
    end

    return extra
end

function _convention_insertion_angles_only(convention::GeometryConvention)
    insertion_angles = [a for a in convention.angle_map if _is_insertion_angle(a)]
    if isempty(insertion_angles)
        insertion_angles = convention.angle_map
    end

    GeometryConvention(
        scale_map=_empty_scale_map(),
        angle_map=insertion_angles,
        translation_map=_empty_translation_map(),
        length_axis=convention.length_axis,
    )
end

function _convention_euler_angles_only(convention::GeometryConvention)
    euler_angles = [a for a in convention.angle_map if !_is_insertion_angle(a)]
    GeometryConvention(
        scale_map=_empty_scale_map(),
        angle_map=euler_angles,
        translation_map=_empty_translation_map(),
        length_axis=convention.length_axis,
    )
end

function _top_width(node, convention::GeometryConvention)
    top_width_aliases = [:TopWidth, :top_width, :topwidth]
    value, found = _resolve_alias(node, top_width_aliases)
    if found !== nothing && value !== nothing
        return value
    end
    return _resolve_value(node, convention.scale_map[:width], :width; default=0.0, warn_missing=false)
end

function _top_height(node, convention::GeometryConvention)
    top_height_aliases = [:TopHeight, :top_height, :topheight]
    value, found = _resolve_alias(node, top_height_aliases)
    if found !== nothing && value !== nothing
        return value
    end
    return _resolve_value(node, convention.scale_map[:thickness], :thickness; default=0.0, warn_missing=false)
end

function _resolve_bool_alias(node, aliases::Vector{Symbol}; default::Bool=false)
    for name in aliases
        raw, present = _try_attr(node, name)
        present || continue
        if raw isa Bool
            return raw
        elseif raw isa Integer
            return raw != 0
        elseif raw isa AbstractFloat
            return raw != 0.0
        elseif raw isa AbstractString
            parsed = lowercase(strip(raw))
            if parsed in ("true", "t", "yes", "y", "1", "on")
                return true
            elseif parsed in ("false", "f", "no", "n", "0", "off")
                return false
            end
        end
    end
    return default
end

function _resolve_order_value(node, order_attr::Symbol)
    raw, present = _try_attr(node, order_attr)
    present || return nothing
    value = _as_float(raw)
    value === nothing && return nothing
    return Int(round(value))
end

function _mtg_has_numeric_attribute(mtg, attr::Symbol)
    found = Ref(false)
    traverse!(mtg) do node
        if found[]
            return
        end
        raw, present = _try_attr(node, attr)
        present || return
        found[] = _as_float(raw) !== nothing
    end
    return found[]
end

function _angles_transform(
    node,
    angles::Vector{AngleConvention};
    warn_missing::Bool=false,
    override_axis_deg::Dict{Symbol,Float64}=Dict{Symbol,Float64}(),
    override_mode::Symbol=:override,
)
    override_mode in (:override, :missing_only) ||
        error("Invalid override_mode '$override_mode'. Expected :override or :missing_only.")

    t = IdentityTransformation()
    for angle in angles
        value, found = _resolve_alias(node, angle.names)
        has_value = found !== nothing && value !== nothing

        if haskey(override_axis_deg, angle.axis) && (override_mode == :override || !has_value)
            value = override_axis_deg[angle.axis]
            has_value = true
            found = :override
        end

        if !has_value
            warn_missing && @warn "No mapped value found for angle. Skipping." axis=angle.axis aliases=angle.names
            continue
        end

        # Override map values are always specified in degrees.
        angle_rad = if found === :override
            deg2rad(value)
        else
            angle.unit == :deg ? deg2rad(value) : value
        end

        rot = _rotation_linear_map(angle.axis, angle_rad)
        if angle.frame == :local
            t = t ∘ rot
        else
            pivot = _pivot_from_attributes(angle.pivot, node; warn_missing=warn_missing)
            t = recenter(rot, pivot) ∘ t
        end
    end

    return t
end

@inline function _compose_aliases(a::Vector{Symbol}, b::Vector{Symbol})
    out = Symbol[]
    append!(out, a)
    append!(out, b)
    unique(out)
end

function _build_rotation_with_columns(dir::SVector{3,Float64}, c2::SVector{3,Float64}, c3::SVector{3,Float64})
    SMatrix{3,3,Float64}(hcat(dir, c2, c3))
end

function _axis_angle_world_rotation(axis::SVector{3,Float64}, angle_rad::Float64)
    naxis = _safe_normalize(axis, _unit_axis(:z))
    SMatrix{3,3,Float64}(RotMatrix(AngleAxis(angle_rad, naxis[1], naxis[2], naxis[3])))
end

function _apply_azimuth_elevation_stage(node, rot::SMatrix{3,3,Float64,9}, options::AmapReconstructionOptions)
    az, az_found = _resolve_alias(node, options.azimuth_aliases)
    el, el_found = _resolve_alias(node, options.elevation_aliases)

    azimuth = (az_found !== nothing && az !== nothing) ? az : 0.0
    elevation = (el_found !== nothing && el !== nothing) ? el : 0.0
    if azimuth == 0.0 && elevation == 0.0
        return rot
    end

    raz = SMatrix{3,3,Float64}(RotMatrix(RotZ(deg2rad(azimuth))))
    rey = SMatrix{3,3,Float64}(RotMatrix(AngleAxis(deg2rad(-elevation), 0.0, 1.0, 0.0)))
    return raz * rey
end

function _apply_orthotropy_stiffness_stage(
    node,
    rot::SMatrix{3,3,Float64,9},
    length_axis::Symbol,
    options::AmapReconstructionOptions,
)
    stiff_deg, stiff_found = _resolve_alias(node, options.stiffness_angle_aliases)
    ortho_deg, ortho_found = _resolve_alias(node, options.orthotropy_aliases)

    has_stiff = stiff_found !== nothing && stiff_deg !== nothing
    has_ortho = ortho_found !== nothing && ortho_deg !== nothing
    (!has_stiff && !has_ortho) && return rot

    angle_rad = has_stiff ? deg2rad(stiff_deg) : deg2rad(ortho_deg)
    angle_rad == 0.0 && return rot

    dir = _safe_normalize(rot * _unit_axis(length_axis), _unit_axis(length_axis))
    dot_zu = clamp(dot(dir, _UP3), -1.0, 1.0)

    if has_stiff
        if (dot_zu <= -0.9999999 && angle_rad < 0.0) || (dot_zu >= 0.9999999 && angle_rad > 0.0)
            return rot
        end
        max_angle = acos(dot_zu)
        if angle_rad < 0.0
            max_angle = pi - max_angle
        end
        if abs(angle_rad) > abs(max_angle)
            angle_rad = sign(angle_rad) * max_angle
        end
    end

    bend_axis = cross(dir, _UP3)
    norm(bend_axis) <= 1e-12 && return rot
    rbend = _axis_angle_world_rotation(bend_axis, angle_rad)
    return rbend * rot
end

function _apply_deviation_stage(node, rot::SMatrix{3,3,Float64,9}, options::AmapReconstructionOptions)
    dev, found = _resolve_alias(node, options.deviation_aliases)
    if found === nothing || dev === nothing || dev == 0.0
        return rot
    end
    rdev = SMatrix{3,3,Float64}(RotMatrix(RotZ(deg2rad(dev))))
    return rdev * rot
end

function _apply_normal_up_projection(rot::SMatrix{3,3,Float64,9})
    dir = _safe_normalize(rot * _unit_axis(:x), _unit_axis(:x))
    normal = _safe_normalize(rot * _unit_axis(:z), _unit_axis(:z))
    plane_normal = cross(dir, _UP3)
    projection = _project_on_plane(plane_normal, normal)
    projection === nothing && return rot

    if dot(projection, _UP3) < 0.0
        projection = -projection
    end
    projection = _safe_normalize(projection, _unit_axis(:z))
    secondary = _safe_normalize(cross(dir, projection), _unit_axis(:y))
    return _build_rotation_with_columns(dir, secondary, projection)
end

function _apply_plagiotropy_projection(rot::SMatrix{3,3,Float64,9})
    dir = _safe_normalize(rot * _unit_axis(:x), _unit_axis(:x))
    secondary = _safe_normalize(rot * _unit_axis(:y), _unit_axis(:y))
    normal = _safe_normalize(rot * _unit_axis(:z), _unit_axis(:z))
    plane_normal = cross(dir, _UP3)

    projection = _project_on_plane(plane_normal, secondary)
    if projection === nothing
        projection = normal
    end
    if dot(projection, _UP3) < 0.0
        projection = -projection
    end
    projection = _safe_normalize(projection, _unit_axis(:y))
    cross_proj_normal = _safe_normalize(cross(dir, projection), _unit_axis(:z))
    return _build_rotation_with_columns(dir, projection, cross_proj_normal)
end

function _apply_projection_stage(node, rot::SMatrix{3,3,Float64,9}, options::AmapReconstructionOptions)
    out = rot
    normal_up = _resolve_bool_alias(node, options.normal_up_aliases; default=false)
    plagiotropy = _resolve_bool_alias(node, options.plagiotropy_aliases; default=false)
    if normal_up
        out = _apply_normal_up_projection(out)
    end
    if plagiotropy
        out = _apply_plagiotropy_projection(out)
    end
    return out
end

function _effective_override_value(
    order::Union{Nothing,Int},
    values::Dict{Int,Float64},
)
    order === nothing && return nothing
    return get(values, order, nothing)
end

function _fallback_insertion_x_angle_deg_amap(
    node,
    parent_node,
    node_convention::GeometryConvention,
    phyllotaxy_aliases::Vector{Symbol},
    verticil_mode::Symbol,
    phyllotaxy_override::Union{Nothing,Float64},
    override_mode::Symbol,
)
    insertion_x_aliases = _insertion_angle_aliases(node_convention, :x)
    if !isempty(insertion_x_aliases) && _has_numeric_alias(node, insertion_x_aliases)
        return 0.0
    end

    has_phyllotaxy = _has_numeric_alias(node, phyllotaxy_aliases)
    extra = if phyllotaxy_override !== nothing && (override_mode == :override || !has_phyllotaxy)
        phyllotaxy_override
    else
        _offset_value(node, phyllotaxy_aliases, 0.0)
    end

    if _verticil_mode(verticil_mode) == :rotation360
        rank, total = _ramification_rank(node, parent_node)
        extra += 360.0 * (rank / total)
    end

    return extra
end

"""
    reconstruct_geometry_from_attributes!(mtg, ref_meshes;
        convention=default_amap_geometry_convention(),
        conventions=Dict(),
        offset_aliases=[:Offset, :offset],
        border_offset_aliases=[:BorderInsertionOffset, :border_insertion_offset, :BorderOffset, :border_offset],
        insertion_mode_aliases=[:InsertionMode, :insertion_mode],
        phyllotaxy_aliases=[:Phyllotaxy, :phyllotaxy, :PHYLLOTAXY],
        verticil_mode=:rotation360,
        amap_options=default_amap_reconstruction_options(),
        dUp=1.0,
        dDwn=1.0,
        warn_missing=false,
        root_align=true,
    )

Reconstruct node geometries from attribute conventions and MTG topology.

When no explicit translation attributes are found (`XX/YY/ZZ` by default), placement follows a
topological convention close to AMAP:

- `"<"`: attach to predecessor top
- `"+"`: attach to bearer at `Offset` (or bearer length if missing)
- `"+"`: default insertion mode is `BORDER`, adding a lateral offset of
  `BorderInsertionOffset` (or bearer top width / 2)
- `"/"`: attach to parent base
"""
function reconstruct_geometry_from_attributes!(mtg, ref_meshes::AbstractDict;
    convention=default_amap_geometry_convention(),
    conventions=Dict(),
    offset_aliases=[:Offset, :offset],
    border_offset_aliases=[:BorderInsertionOffset, :border_insertion_offset, :BorderOffset, :border_offset],
    insertion_mode_aliases=[:InsertionMode, :insertion_mode],
    phyllotaxy_aliases=[:Phyllotaxy, :phyllotaxy, :PHYLLOTAXY],
    verticil_mode=:rotation360,
    amap_options=default_amap_reconstruction_options(),
    dUp=1.0,
    dDwn=1.0,
    warn_missing=false,
    root_align=true,
)
    offset_aliases_norm = _normalize_aliases(offset_aliases)
    border_offset_aliases_norm = _normalize_aliases(border_offset_aliases)
    insertion_mode_aliases_norm = _normalize_aliases(insertion_mode_aliases)
    phyllotaxy_aliases_norm = _normalize_aliases(phyllotaxy_aliases)
    verticil_mode_norm = _verticil_mode(verticil_mode)
    amap_cfg = amap_options
    amap_cfg isa AmapReconstructionOptions ||
        error("Invalid `amap_options` value. Expected `AmapReconstructionOptions`.")

    amap_insertion_mode_aliases = _compose_aliases(amap_cfg.insertion_mode_aliases, amap_cfg.insertion_aliases)
    effective_phyllotaxy_aliases = phyllotaxy_aliases_norm == [:Phyllotaxy, :phyllotaxy, :PHYLLOTAXY] ?
                                   amap_cfg.phyllotaxy_aliases : phyllotaxy_aliases_norm
    effective_verticil_mode = verticil_mode_norm == :rotation360 ? amap_cfg.verticil_mode : verticil_mode_norm

    if amap_cfg.auto_compute_branching_order &&
       !_mtg_has_numeric_attribute(mtg, amap_cfg.order_attribute)
        MultiScaleTreeGraph.branching_order!(mtg; ascend=true)
    end

    root_rotation = if root_align && convention.length_axis == :x
        SMatrix{3,3,Float64}(RotMatrix(AngleAxis(-pi / 2, 0.0, 1.0, 0.0)))
    else
        _I3
    end

    base_pos = IdDict{Any,SVector{3,Float64}}()
    top_pos = IdDict{Any,SVector{3,Float64}}()
    direction = IdDict{Any,SVector{3,Float64}}()
    base_rot = IdDict{Any,SMatrix{3,3,Float64,9}}()

    traverse!(mtg) do node
        node_convention = _resolve_node_convention(node, convention, conventions)
        conv_insertion_only = _convention_insertion_angles_only(node_convention)

        explicit_translation = _has_explicit_translation(node, node_convention)

        parent_node = isroot(node) ? nothing : parent(node)
        link_type = isroot(node) ? nothing : link(node)

        current_base_rot = root_rotation
        current_base_pos = _ZERO3

        if !explicit_translation && parent_node !== nothing
            if link_type == "<"
                if haskey(base_rot, parent_node)
                    current_base_rot = base_rot[parent_node]
                    current_base_pos = get(top_pos, parent_node, _ZERO3)
                end
            elseif link_type == "+"
                if haskey(base_rot, parent_node)
                    parent_conv = _resolve_node_convention(parent_node, convention, conventions)
                    parent_length = _resolve_value(
                        parent_node,
                        parent_conv.scale_map[:length],
                        :length;
                        default=1.0,
                        warn_missing=false,
                    )
                    offset_val = _offset_value(node, offset_aliases_norm, parent_length)
                    current_base_rot = base_rot[parent_node]
                    current_base_pos = get(base_pos, parent_node, _ZERO3) +
                                       get(direction, parent_node, _unit_axis(parent_conv.length_axis)) * offset_val
                end
            elseif link_type == "/"
                if haskey(base_rot, parent_node)
                    current_base_rot = base_rot[parent_node]
                    current_base_pos = get(base_pos, parent_node, _ZERO3)
                end
            else
                if haskey(base_rot, parent_node)
                    current_base_rot = base_rot[parent_node]
                    current_base_pos = get(base_pos, parent_node, _ZERO3)
                end
            end
        end

        world_t = nothing
        world_angles_t = nothing

        conv_scale_only = _convention_scale_only(node_convention)
        conv_euler_only = _convention_euler_angles_only(node_convention)

        if _resolve_bool_alias(node, amap_cfg.orientation_reset_aliases; default=false)
            current_base_rot = root_rotation
        end

        if explicit_translation
            tx = _resolve_value(node, node_convention.translation_map[:x], :x; default=0.0, warn_missing=warn_missing)
            ty = _resolve_value(node, node_convention.translation_map[:y], :y; default=0.0, warn_missing=warn_missing)
            tz = _resolve_value(node, node_convention.translation_map[:z], :z; default=0.0, warn_missing=warn_missing)
            current_base_pos = SVector{3,Float64}(tx, ty, tz)
            if !isroot(node) && !_resolve_bool_alias(node, amap_cfg.orientation_reset_aliases; default=false)
                current_base_rot = _I3
            end
        end

        order_value = _resolve_order_value(node, amap_cfg.order_attribute)
        insertion_y_override = _effective_override_value(order_value, amap_cfg.insertion_y_by_order)
        phyllotaxy_override = _effective_override_value(order_value, amap_cfg.phyllotaxy_by_order)

        override_by_axis = Dict{Symbol,Float64}()
        if insertion_y_override !== nothing
            override_by_axis[:y] = insertion_y_override
        end

        local_scale_t = transformation_from_attributes(node; convention=conv_scale_only, warn_missing=warn_missing)
        local_insertion_t = _angles_transform(
            node,
            conv_insertion_only.angle_map;
            warn_missing=warn_missing,
            override_axis_deg=override_by_axis,
            override_mode=amap_cfg.order_override_mode,
        )
        local_euler_t = transformation_from_attributes(node; convention=conv_euler_only, warn_missing=warn_missing)

        if link_type == "+" && parent_node !== nothing
            extra_x_deg = _fallback_insertion_x_angle_deg_amap(
                node,
                parent_node,
                node_convention,
                effective_phyllotaxy_aliases,
                effective_verticil_mode,
                phyllotaxy_override,
                amap_cfg.order_override_mode,
            )
            if extra_x_deg != 0.0
                local_insertion_t = local_insertion_t ∘ _rotation_linear_map(:x, deg2rad(extra_x_deg))
            end
        end

        base_t = _frame_transform(current_base_rot, current_base_pos)

        if !explicit_translation && link_type == "+" && parent_node !== nothing && haskey(base_rot, parent_node)
            mode_aliases = _compose_aliases(insertion_mode_aliases_norm, amap_insertion_mode_aliases)
            mode = _insertion_mode(node, mode_aliases)
            if mode != :CENTER
                parent_conv = _resolve_node_convention(parent_node, convention, conventions)
                parent_dir = _safe_normalize(
                    get(direction, parent_node, _unit_axis(parent_conv.length_axis)),
                    _unit_axis(parent_conv.length_axis),
                )

                insertion_rot = _rotation_part(base_t ∘ local_insertion_t)
                main_dir = _safe_normalize(
                    insertion_rot * _unit_axis(node_convention.length_axis),
                    _unit_axis(node_convention.length_axis),
                )
                fallback_dir = _safe_normalize(
                    insertion_rot * _unit_axis(_normal_axis(node_convention.length_axis)),
                    _unit_axis(_secondary_axis(node_convention.length_axis)),
                )
                parent_secondary = _safe_normalize(current_base_rot * _unit_axis(:y), _unit_axis(:y))
                parent_normal = _safe_normalize(current_base_rot * _unit_axis(:z), _unit_axis(:z))

                border_dir = nothing
                if mode == :BORDER
                    border_dir = _project_on_plane(parent_dir, main_dir)
                    if border_dir === nothing || dot(border_dir, border_dir) <= 0.01
                        border_dir = _project_on_plane(parent_dir, fallback_dir)
                        border_dir === nothing || (border_dir = -border_dir)
                    end
                elseif mode == :WIDTH
                    border_dir = dot(parent_secondary, main_dir) >= 0.0 ? parent_secondary : -parent_secondary
                elseif mode == :HEIGHT
                    border_dir = dot(parent_normal, main_dir) >= 0.0 ? parent_normal : -parent_normal
                end

                if border_dir !== nothing
                    border_dir = _safe_normalize(border_dir, _unit_axis(_secondary_axis(node_convention.length_axis)))
                    parent_top_width = _top_width(parent_node, parent_conv)
                    parent_top_height = _top_height(parent_node, parent_conv)
                    default_border_offset = if mode == :HEIGHT
                        parent_top_height / 2
                    else
                        parent_top_width / 2
                    end
                    border_offset = _offset_value(node, border_offset_aliases_norm, default_border_offset)
                    if border_offset != 0.0
                        current_base_pos = current_base_pos + border_dir * border_offset
                        base_t = _frame_transform(current_base_rot, current_base_pos)
                    end
                end
            end
        end

        rot = _rotation_part(base_t ∘ local_insertion_t)
        rot = _apply_azimuth_elevation_stage(node, rot, amap_cfg)
        rot = _apply_orthotropy_stiffness_stage(node, rot, node_convention.length_axis, amap_cfg)
        rot = _apply_deviation_stage(node, rot, amap_cfg)
        rot = rot * _rotation_part(local_euler_t)
        rot = _apply_projection_stage(node, rot, amap_cfg)

        lin = rot * _linear_part(local_scale_t)
        world_t = AffineMap(Matrix(lin), current_base_pos)
        world_angles_t = AffineMap(Matrix(rot), current_base_pos)

        p0 = _to_svec3(world_t(_ZERO3))
        p1 = _to_svec3(world_t(_unit_axis(node_convention.length_axis)))
        rot = _rotation_part(world_angles_t)
        dir = _normalize_direction(p1 - p0, rot, node_convention.length_axis)

        base_pos[node] = p0
        top_pos[node] = p1
        direction[node] = dir
        base_rot[node] = rot

        ref_mesh = _resolve_ref_mesh(node, ref_meshes)
        if ref_mesh !== nothing
            node[:geometry] = Geometry(ref_mesh=ref_mesh, transformation=world_t, dUp=dUp, dDwn=dDwn)
        end
    end

    mtg
end

function set_geometry_from_attributes!(mtg::MultiScaleTreeGraph.Node, ref_meshes::AbstractDict;
    convention=default_amap_geometry_convention(),
    conventions=Dict(),
    offset_aliases=[:Offset, :offset],
    border_offset_aliases=[:BorderInsertionOffset, :border_insertion_offset, :BorderOffset, :border_offset],
    insertion_mode_aliases=[:InsertionMode, :insertion_mode],
    phyllotaxy_aliases=[:Phyllotaxy, :phyllotaxy, :PHYLLOTAXY],
    verticil_mode=:rotation360,
    amap_options=default_amap_reconstruction_options(),
    dUp=1.0,
    dDwn=1.0,
    warn_missing=false,
    root_align=true,
)
    reconstruct_geometry_from_attributes!(
        mtg,
        ref_meshes;
        convention=convention,
        conventions=conventions,
        offset_aliases=offset_aliases,
        border_offset_aliases=border_offset_aliases,
        insertion_mode_aliases=insertion_mode_aliases,
        phyllotaxy_aliases=phyllotaxy_aliases,
        verticil_mode=verticil_mode,
        amap_options=amap_options,
        dUp=dUp,
        dDwn=dDwn,
        warn_missing=warn_missing,
        root_align=root_align,
    )
end
