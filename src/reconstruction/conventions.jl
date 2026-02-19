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

function _top_width(node, convention::GeometryConvention)
    top_width_aliases = [:TopWidth, :top_width, :topwidth]
    value, found = _resolve_alias(node, top_width_aliases)
    if found !== nothing && value !== nothing
        return value
    end
    return _resolve_value(node, convention.scale_map[:width], :width; default=0.0, warn_missing=false)
end

"""
    reconstruct_geometry_from_attributes!(mtg, ref_meshes;
        convention=default_amap_geometry_convention(),
        conventions=Dict(),
        offset_aliases=[:Offset, :offset],
        border_offset_aliases=[:BorderInsertionOffset, :border_insertion_offset, :BorderOffset, :border_offset],
        insertion_mode_aliases=[:InsertionMode, :insertion_mode],
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
    dUp=1.0,
    dDwn=1.0,
    warn_missing=false,
    root_align=true,
)
    offset_aliases_norm = _normalize_aliases(offset_aliases)
    border_offset_aliases_norm = _normalize_aliases(border_offset_aliases)
    insertion_mode_aliases_norm = _normalize_aliases(insertion_mode_aliases)

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
        conv_no_translation = _convention_without_translation(node_convention)
        conv_angles_only = _convention_angles_only(node_convention)
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

        if explicit_translation
            world_t = transformation_from_attributes(node; convention=node_convention, warn_missing=warn_missing)
            world_angles_t = transformation_from_attributes(node; convention=conv_angles_only, warn_missing=warn_missing)
        else
            base_t = _frame_transform(current_base_rot, current_base_pos)
            local_t = transformation_from_attributes(node; convention=conv_no_translation, warn_missing=warn_missing)
            local_angles_t = transformation_from_attributes(node; convention=conv_angles_only, warn_missing=warn_missing)
            local_insertion_t = transformation_from_attributes(node; convention=conv_insertion_only, warn_missing=warn_missing)

            if link_type == "+" && parent_node !== nothing && haskey(base_rot, parent_node)
                mode = _insertion_mode(node, insertion_mode_aliases_norm)
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

                    border_dir = _project_on_plane(parent_dir, main_dir)
                    if border_dir === nothing || dot(border_dir, border_dir) <= 0.01
                        border_dir = _project_on_plane(parent_dir, fallback_dir)
                        border_dir === nothing || (border_dir = -border_dir)
                    end

                    if border_dir !== nothing
                        border_dir = _safe_normalize(border_dir, _unit_axis(_secondary_axis(node_convention.length_axis)))
                        parent_top_width = _top_width(parent_node, parent_conv)
                        border_offset = _offset_value(node, border_offset_aliases_norm, parent_top_width / 2)
                        if border_offset != 0.0
                            current_base_pos = current_base_pos + border_dir * border_offset
                            base_t = _frame_transform(current_base_rot, current_base_pos)
                        end
                    end
                end
            end

            world_t = base_t ∘ local_t
            world_angles_t = base_t ∘ local_angles_t
        end

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
        dUp=dUp,
        dDwn=dDwn,
        warn_missing=warn_missing,
        root_align=root_align,
    )
end
