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
            :thickness => [:Thickness, :thickness, :Depth, :depth, :Height, :height, :H, :h],
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
            :thickness => [:Thickness, :thickness, :Depth, :depth, :Height, :height, :H, :h],
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

function _resolve_raw_alias(node, aliases::Vector{Symbol})
    for name in aliases
        raw, present = _try_attr(node, name)
        present || continue
        raw === nothing && continue
        raw === missing && continue
        return raw, name
    end
    return nothing, nothing
end

function _resolve_value(node, aliases::Vector{Symbol}, label::Symbol; default=0.0, warn_missing=false)
    value, found = _resolve_alias(node, aliases)
    if found === nothing
        warn_missing && @warn "No mapped value found for '$label'. Using default $default." aliases = aliases
        return Float64(default)
    end
    if value === nothing
        warn_missing && @warn "Mapped value for '$label' is not numeric. Using default $default." attr = found
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
            warn_missing && @warn "No mapped value found for angle. Skipping." axis = angle.axis aliases = angle.names
            continue
        elseif value === nothing
            warn_missing && @warn "Mapped angle value is not numeric. Skipping." attr = found axis = angle.axis
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
const _TOP_WIDTH_ALIASES = [:TopWidth, :top_width, :topwidth]
const _TOP_HEIGHT_ALIASES = [:TopHeight, :top_height, :topheight]

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

@inline function _predecessor_in_axis(node)
    isroot(node) && return nothing
    return link(node) == :< ? parent(node) : nothing
end

function _first_successor_in_axis(node)
    for child in children(node)
        link(child) == :< && return child
    end
    return nothing
end

function _position_in_axis(node)
    pos = 1
    cur = node
    while true
        pred = _predecessor_in_axis(cur)
        pred === nothing && return pos
        pos += 1
        cur = pred
    end
end

function _has_original_numeric(original_values::IdDict{Any,Union{Nothing,Float64}}, node)
    haskey(original_values, node) && original_values[node] !== nothing
end

function _interpolate_measure(
    node,
    original_values::IdDict{Any,Union{Nothing,Float64}},
)
    prev_value = nothing
    pos_a = 0
    n = node
    while true
        n = _predecessor_in_axis(n)
        n === nothing && break
        if _has_original_numeric(original_values, n)
            prev_value = original_values[n]
            pos_a = _position_in_axis(n) + 1
            break
        end
    end

    next_value = nothing
    pos_b = 0
    n = node
    while true
        n = _first_successor_in_axis(n)
        n === nothing && break
        if _has_original_numeric(original_values, n)
            next_value = original_values[n]
            pos_b = _position_in_axis(n) + 1
            break
        end
    end

    if prev_value !== nothing && next_value !== nothing && pos_b != pos_a
        return (_position_in_axis(node) + 1 - pos_a) * (next_value - prev_value) / (pos_b - pos_a) + prev_value
    elseif prev_value !== nothing
        return prev_value
    elseif next_value !== nothing
        return next_value
    end
    return nothing
end

function _set_alias_value!(node, aliases::Vector{Symbol}, value::Float64)
    isempty(aliases) && return
    node[first(aliases)] = value
end

function _component_children(node)
    out = Any[]
    for child in children(node)
        link(child) == :/ || continue
        cur = child
        while cur !== nothing
            push!(out, cur)
            cur = _first_successor_in_axis(cur)
        end
    end
    return out
end

function _components_are_successive(components_nodes)
    isempty(components_nodes) && return false
    component_set = Set(components_nodes)
    for n in components_nodes
        pred = _predecessor_in_axis(n)
        if pred !== nothing && (pred in component_set)
            return true
        end
    end
    return false
end

@inline function _complex_node(node)
    isroot(node) && return nothing

    lnk = link(node)
    if lnk == :/
        return parent(node)
    elseif lnk == :<
        cur = node
        while true
            pred = _predecessor_in_axis(cur)
            pred === nothing && return nothing
            if link(pred) == :/
                return parent(pred)
            end
            cur = pred
        end
    end

    return nothing
end

function _prepare_amap_allometry!(
    mtg,
    default_convention::GeometryConvention,
    conventions::AbstractDict,
    options::AmapReconstructionOptions,
)
    options.allometry_enabled || return

    nodes = Any[]
    traverse!(mtg) do node
        push!(nodes, node)
    end

    orig_length = IdDict{Any,Union{Nothing,Float64}}()
    orig_width = IdDict{Any,Union{Nothing,Float64}}()
    orig_height = IdDict{Any,Union{Nothing,Float64}}()
    orig_top_width = IdDict{Any,Union{Nothing,Float64}}()
    orig_top_height = IdDict{Any,Union{Nothing,Float64}}()

    for node in nodes
        conv = _resolve_node_convention(node, default_convention, conventions)
        len, _ = _resolve_alias(node, conv.scale_map[:length])
        wid, _ = _resolve_alias(node, conv.scale_map[:width])
        hei, _ = _resolve_alias(node, conv.scale_map[:thickness])
        tw, _ = _resolve_alias(node, _TOP_WIDTH_ALIASES)
        th, _ = _resolve_alias(node, _TOP_HEIGHT_ALIASES)
        orig_length[node] = len
        orig_width[node] = wid
        orig_height[node] = hei
        orig_top_width[node] = tw
        orig_top_height[node] = th
    end

    for node in nodes
        conv = _resolve_node_convention(node, default_convention, conventions)
        components = _component_children(node)
        is_terminal = isempty(components)

        measured_length = orig_length[node]
        measured_width = orig_width[node]
        measured_height = orig_height[node]

        if options.allometry_interpolate_width_height
            measured_width === nothing && (measured_width = _interpolate_measure(node, orig_width))
            measured_height === nothing && (measured_height = _interpolate_measure(node, orig_height))
        end

        if measured_width !== nothing && measured_height === nothing
            measured_height = measured_width
        elseif measured_height !== nothing && measured_width === nothing
            measured_width = measured_height
        end

        top_width = orig_top_width[node]
        top_height = orig_top_height[node]
        if top_width !== nothing && top_height === nothing
            top_height = top_width
        elseif top_height !== nothing && top_width === nothing
            top_width = top_height
        end

        if measured_length !== nothing
            _set_alias_value!(node, conv.scale_map[:length], measured_length)
        end
        if measured_width !== nothing
            _set_alias_value!(node, conv.scale_map[:width], measured_width)
        end
        if measured_height !== nothing
            _set_alias_value!(node, conv.scale_map[:thickness], measured_height)
        end
        if top_width !== nothing
            _set_alias_value!(node, _TOP_WIDTH_ALIASES, top_width)
        end
        if top_height !== nothing
            _set_alias_value!(node, _TOP_HEIGHT_ALIASES, top_height)
        end

        if !is_terminal
            if measured_length !== nothing || measured_width !== nothing || measured_height !== nothing
                split_length = _components_are_successive(components)
                n_comp = max(length(components), 1)
                for component_node in components
                    component_conv = _resolve_node_convention(component_node, default_convention, conventions)
                    comp_len_orig = get(orig_length, component_node, nothing)
                    comp_wid_orig = get(orig_width, component_node, nothing)
                    comp_hei_orig = get(orig_height, component_node, nothing)

                    if measured_length !== nothing && comp_len_orig === nothing
                        len_value = split_length ? (measured_length / n_comp) : measured_length
                        _set_alias_value!(component_node, component_conv.scale_map[:length], len_value)
                    end
                    if measured_width !== nothing && comp_wid_orig === nothing
                        _set_alias_value!(component_node, component_conv.scale_map[:width], measured_width)
                    end
                    if measured_height !== nothing && comp_hei_orig === nothing
                        _set_alias_value!(component_node, component_conv.scale_map[:thickness], measured_height)
                    end
                end
            else
                # AMAP allometry: non-terminal node without measured allometry collapses to zero size.
                _set_alias_value!(node, conv.scale_map[:length], 0.0)
                _set_alias_value!(node, conv.scale_map[:width], 0.0)
                _set_alias_value!(node, conv.scale_map[:thickness], 0.0)
            end
        else
            # AMAP allometry defaults for terminal nodes only when still missing
            # after interpolation/propagation.
            cur_len, _ = _resolve_alias(node, conv.scale_map[:length])
            cur_wid, _ = _resolve_alias(node, conv.scale_map[:width])
            cur_hei, _ = _resolve_alias(node, conv.scale_map[:thickness])

            cur_len === nothing &&
                _set_alias_value!(node, conv.scale_map[:length], options.allometry_default_length)
            cur_wid === nothing &&
                _set_alias_value!(node, conv.scale_map[:width], options.allometry_default_width)
            cur_hei === nothing &&
                _set_alias_value!(node, conv.scale_map[:thickness], options.allometry_default_height)
        end
    end

    # Smooth predecessor top diameters/widths when missing.
    for node in nodes
        pred = _predecessor_in_axis(node)
        pred === nothing && continue
        symbol(pred) == symbol(node) || continue

        node_conv = _resolve_node_convention(node, default_convention, conventions)
        pred_conv = _resolve_node_convention(pred, default_convention, conventions)
        node_w = _resolve_value(node, node_conv.scale_map[:width], :width; default=options.allometry_default_width, warn_missing=false)
        node_h = _resolve_value(node, node_conv.scale_map[:thickness], :thickness; default=options.allometry_default_height, warn_missing=false)

        pred_top_w, _ = _resolve_alias(pred, _TOP_WIDTH_ALIASES)
        pred_top_h, _ = _resolve_alias(pred, _TOP_HEIGHT_ALIASES)
        if pred_top_w === nothing
            _set_alias_value!(pred, _TOP_WIDTH_ALIASES, node_w)
        end
        if pred_top_h === nothing
            _set_alias_value!(pred, _TOP_HEIGHT_ALIASES, node_h)
        end

        # Keep width/height coherent on predecessor if only one was originally measured.
        pred_w, _ = _resolve_alias(pred, pred_conv.scale_map[:width])
        pred_h, _ = _resolve_alias(pred, pred_conv.scale_map[:thickness])
        if pred_w !== nothing && pred_h === nothing
            _set_alias_value!(pred, pred_conv.scale_map[:thickness], pred_w)
        elseif pred_h !== nothing && pred_w === nothing
            _set_alias_value!(pred, pred_conv.scale_map[:width], pred_h)
        end
    end

    # Complex accumulation from terminal nodes only.
    for node in nodes
        isempty(_component_children(node)) || continue
        node_conv = _resolve_node_convention(node, default_convention, conventions)
        node_length = _resolve_value(node, node_conv.scale_map[:length], :length; default=options.allometry_default_length, warn_missing=false)
        node_width = _resolve_value(node, node_conv.scale_map[:width], :width; default=options.allometry_default_width, warn_missing=false)

        complex = _complex_node(node)
        while complex !== nothing
            complex_conv = _resolve_node_convention(complex, default_convention, conventions)

            if get(orig_length, complex, nothing) === nothing
                cur_len, _ = _resolve_alias(complex, complex_conv.scale_map[:length])
                _set_alias_value!(complex, complex_conv.scale_map[:length], (cur_len === nothing ? 0.0 : cur_len) + node_length)
            end

            if get(orig_width, complex, nothing) === nothing
                cur_w, _ = _resolve_alias(complex, complex_conv.scale_map[:width])
                new_w = max(cur_w === nothing ? 0.0 : cur_w, node_width)
                _set_alias_value!(complex, complex_conv.scale_map[:width], new_w)
                if get(orig_height, complex, nothing) === nothing
                    _set_alias_value!(complex, complex_conv.scale_map[:thickness], new_w)
                end
            end

            complex = _complex_node(complex)
        end
    end
end

function _resolve_scale_values(
    node,
    convention::GeometryConvention;
    warn_missing::Bool=false,
    length_override::Union{Nothing,Float64}=nothing,
)
    length_val = _resolve_value(node, convention.scale_map[:length], :length; default=1.0, warn_missing=warn_missing)
    width_val = _resolve_value(node, convention.scale_map[:width], :width; default=1.0, warn_missing=warn_missing)
    thickness_val = _resolve_value(
        node,
        convention.scale_map[:thickness],
        :thickness;
        default=width_val,
        warn_missing=warn_missing,
    )

    if length_override !== nothing
        length_val = length_override
    end

    return length_val, width_val, thickness_val
end

@inline function _scale_linear(length_axis::Symbol, length_val::Float64, width_val::Float64, thickness_val::Float64)
    sx, sy, sz = _scale_components(length_axis, length_val, width_val, thickness_val)
    return SMatrix{3,3,Float64}(sx, 0.0, 0.0, 0.0, sy, 0.0, 0.0, 0.0, sz)
end

function _resolve_endpoint_position(node, options::AmapReconstructionOptions; warn_missing::Bool=false)
    ex, fx = _resolve_alias(node, options.endpoint_x_aliases)
    ey, fy = _resolve_alias(node, options.endpoint_y_aliases)
    ez, fz = _resolve_alias(node, options.endpoint_z_aliases)

    has_any = (fx !== nothing) || (fy !== nothing) || (fz !== nothing)
    has_all = (fx !== nothing) && (fy !== nothing) && (fz !== nothing) &&
              (ex !== nothing) && (ey !== nothing) && (ez !== nothing)

    if has_any && !has_all
        warn_missing && @warn "Incomplete EndX/EndY/EndZ endpoint ignored for node." found = (fx, fy, fz)
        return nothing
    end

    return has_all ? SVector{3,Float64}(ex, ey, ez) : nothing
end

@inline function _coordinate_delegate_mode(mode::Symbol)
    mode in (:topology_default, :explicit_rewire_previous, :explicit_start_end_required) ||
        error(
            "Invalid coordinate_delegate_mode '$mode'. Expected :topology_default, :explicit_rewire_previous or :explicit_start_end_required.",
        )
    mode
end

function _rotation_from_direction_world_up(direction::SVector{3,Float64}, length_axis::Symbol)
    dir = _safe_normalize(direction, _unit_axis(length_axis))
    lateral = cross(_UP3, dir)
    if norm(lateral) <= 1e-6
        lateral = cross(_unit_axis(:y), dir)
    end
    secondary = _normalize_perpendicular(
        lateral,
        dir,
        _any_perpendicular(dir, _unit_axis(_secondary_axis(length_axis))),
    )
    normal = _normalize_perpendicular(
        cross(dir, secondary),
        dir,
        _any_perpendicular(dir, _unit_axis(_normal_axis(length_axis))),
    )
    _build_rotation_from_local_axes(length_axis, dir, secondary, normal)
end

@inline function _coordinate_delegate2_previous_node(parent_node, link_type)
    parent_node === nothing && return nothing
    return link_type == :/ ? nothing : parent_node
end

function _apply_coordinate_delegate2_previous!(
    previous_node,
    target_pos::SVector{3,Float64},
    default_convention::GeometryConvention,
    conventions::AbstractDict,
    ref_meshes::AbstractDict,
    ref_mesh_selector::Union{Nothing,Function},
    base_pos::IdDict{Any,SVector{3,Float64}},
    top_pos::IdDict{Any,SVector{3,Float64}},
    direction::IdDict{Any,SVector{3,Float64}},
    base_rot::IdDict{Any,SMatrix{3,3,Float64,9}};
    dUp::Real=1.0,
    dDwn::Real=1.0,
    warn_missing::Bool=false,
)
    haskey(base_pos, previous_node) || return false

    prev_base = base_pos[previous_node]
    delta = target_pos - prev_base
    len = norm(delta)
    len > 1e-12 || return false

    prev_conv = _resolve_node_convention(previous_node, default_convention, conventions)
    prev_rot = _rotation_from_direction_world_up(delta, prev_conv.length_axis)
    prev_length, prev_width, prev_thickness = _resolve_scale_values(
        previous_node,
        prev_conv;
        warn_missing=warn_missing,
        length_override=len,
    )

    prev_lin = prev_rot * _scale_linear(prev_conv.length_axis, prev_length, prev_width, prev_thickness)
    prev_world_t = AffineMap(Matrix(prev_lin), prev_base)
    prev_world_angles_t = AffineMap(Matrix(prev_rot), prev_base)

    p0 = prev_base
    p1 = _to_svec3(prev_world_t(_unit_axis(prev_conv.length_axis)))
    r0 = _rotation_part(prev_world_angles_t)
    d0 = _normalize_direction(p1 - p0, r0, prev_conv.length_axis)

    base_pos[previous_node] = p0
    top_pos[previous_node] = p1
    direction[previous_node] = d0
    base_rot[previous_node] = r0

    ref_mesh = _resolve_ref_mesh(previous_node, ref_meshes, ref_mesh_selector)
    if ref_mesh !== nothing
        previous_node[:geometry] = Geometry(
            ref_mesh=ref_mesh,
            transformation=prev_world_t,
            dUp=dUp,
            dDwn=dDwn,
        )
    end
    return true
end

function _rotation_from_direction_with_hint(
    direction::SVector{3,Float64},
    length_axis::Symbol,
    hint_rot::SMatrix{3,3,Float64,9},
)
    dir = _safe_normalize(direction, _unit_axis(length_axis))
    secondary_axis = _secondary_axis(length_axis)
    normal_axis = _normal_axis(length_axis)
    hint_secondary = _axis_column(hint_rot, secondary_axis)
    hint_normal = _axis_column(hint_rot, normal_axis)

    secondary = _normalize_perpendicular(hint_secondary, dir, _any_perpendicular(dir, hint_normal))
    normal = _normalize_perpendicular(cross(dir, secondary), dir, _any_perpendicular(dir, hint_normal))
    return _build_rotation_from_local_axes(length_axis, dir, secondary, normal)
end

function _resolve_ref_mesh(node, ref_meshes::AbstractDict, ref_mesh_selector::Union{Nothing,Function}=nothing)
    if ref_mesh_selector !== nothing
        selected = ref_mesh_selector(node)
        if selected !== nothing
            selected isa RefMesh || error("`ref_mesh_selector` must return `RefMesh` or `nothing`, got $(typeof(selected)).")
            return selected
        end
    end

    name = symbol(node)
    haskey(ref_meshes, name) && return ref_meshes[name]
    name_str = String(name)
    haskey(ref_meshes, name_str) && return ref_meshes[name_str]
    return nothing
end

function _resolve_node_convention(node, default_convention::GeometryConvention, conventions::AbstractDict)
    isempty(conventions) && return default_convention
    name = symbol(node)
    haskey(conventions, name) && return conventions[name]
    name_str = String(name)
    haskey(conventions, name_str) && return conventions[name_str]
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
    mode == "SURFACE" && return :BORDER
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
        if link(child) == :+ && symbol(child) == node_symbol
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
    value, found = _resolve_alias(node, _TOP_WIDTH_ALIASES)
    if found !== nothing && value !== nothing
        return value
    end
    return _resolve_value(node, convention.scale_map[:width], :width; default=0.0, warn_missing=false)
end

function _top_height(node, convention::GeometryConvention)
    value, found = _resolve_alias(node, _TOP_HEIGHT_ALIASES)
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
            warn_missing && @warn "No mapped value found for angle. Skipping." axis = angle.axis aliases = angle.names
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

@inline function _axis_column(rot::SMatrix{3,3,Float64,9}, axis::Symbol)
    _safe_normalize(rot * _unit_axis(axis), _unit_axis(axis))
end

function _build_rotation_from_local_axes(
    length_axis::Symbol,
    dir::SVector{3,Float64},
    secondary::SVector{3,Float64},
    normal::SVector{3,Float64},
)
    secondary_axis = _secondary_axis(length_axis)
    normal_axis = _normal_axis(length_axis)

    x_axis = if length_axis == :x
        dir
    elseif secondary_axis == :x
        secondary
    else
        normal
    end
    y_axis = if length_axis == :y
        dir
    elseif secondary_axis == :y
        secondary
    else
        normal
    end
    z_axis = if length_axis == :z
        dir
    elseif secondary_axis == :z
        secondary
    else
        normal
    end

    SMatrix{3,3,Float64}(hcat(x_axis, y_axis, z_axis))
end

function _normalize_perpendicular(
    vec::SVector{3,Float64},
    direction::SVector{3,Float64},
    fallback::SVector{3,Float64},
)
    perp = vec - dot(vec, direction) * direction
    n = norm(perp)
    if n <= 1e-12
        fb = fallback - dot(fallback, direction) * direction
        nf = norm(fb)
        return nf <= 1e-12 ? _unit_axis(:y) : (fb / nf)
    end
    perp / n
end

function _any_perpendicular(direction::SVector{3,Float64}, preferred::SVector{3,Float64})
    candidate = preferred - dot(preferred, direction) * direction
    n = norm(candidate)
    if n > 1e-12
        return candidate / n
    end

    for axis in (_unit_axis(:x), _unit_axis(:y), _unit_axis(:z))
        candidate = axis - dot(axis, direction) * direction
        n = norm(candidate)
        if n > 1e-12
            return candidate / n
        end
    end

    return _unit_axis(:y)
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

function _apply_normal_up_projection(rot::SMatrix{3,3,Float64,9}, length_axis::Symbol)
    secondary_axis = _secondary_axis(length_axis)
    normal_axis = _normal_axis(length_axis)

    dir = _axis_column(rot, length_axis)
    secondary = _axis_column(rot, secondary_axis)
    normal = _axis_column(rot, normal_axis)
    plane_normal = cross(dir, _UP3)
    projection = _project_on_plane(plane_normal, normal)
    projection === nothing && return rot

    if dot(projection, _UP3) < 0.0
        projection = -projection
    end
    projection = _normalize_perpendicular(projection, dir, _any_perpendicular(dir, normal))
    secondary_new = _normalize_perpendicular(cross(dir, projection), dir, _any_perpendicular(dir, secondary))
    return _build_rotation_from_local_axes(length_axis, dir, secondary_new, projection)
end

function _apply_plagiotropy_projection(rot::SMatrix{3,3,Float64,9}, length_axis::Symbol)
    secondary_axis = _secondary_axis(length_axis)
    normal_axis = _normal_axis(length_axis)

    dir = _axis_column(rot, length_axis)
    secondary = _axis_column(rot, secondary_axis)
    normal = _axis_column(rot, normal_axis)
    plane_normal = cross(dir, _UP3)

    projection = _project_on_plane(plane_normal, secondary)
    if projection === nothing
        projection = normal
    end
    if dot(projection, _UP3) < 0.0
        projection = -projection
    end
    projection = _normalize_perpendicular(projection, dir, _any_perpendicular(dir, secondary))
    normal_new = _normalize_perpendicular(cross(dir, projection), dir, _any_perpendicular(dir, normal))
    return _build_rotation_from_local_axes(length_axis, dir, projection, normal_new)
end

function _apply_projection_stage(
    node,
    rot::SMatrix{3,3,Float64,9},
    length_axis::Symbol,
    options::AmapReconstructionOptions,
)
    out = rot
    normal_up = _resolve_bool_alias(node, options.normal_up_aliases; default=false)
    plagiotropy = _resolve_bool_alias(node, options.plagiotropy_aliases; default=false)
    if normal_up
        out = _apply_normal_up_projection(out, length_axis)
    end
    if plagiotropy
        out = _apply_plagiotropy_projection(out, length_axis)
    end
    return out
end

const _CONSTRAINT_TYPE_ALIASES = [:ConstraintType, :constraint_type, :GeometricalConstraintType, :geometrical_constraint_type]
const _CONSTRAINT_PRIMARY_ANGLE_ALIASES = [:ConstraintAngle, :constraint_angle, :PrimaryAngle, :primary_angle, :ConeAngle, :cone_angle]
const _CONSTRAINT_SECONDARY_ANGLE_ALIASES = [:ConstraintSecondaryAngle, :constraint_secondary_angle, :SecondaryAngle, :secondary_angle]
const _CONSTRAINT_RADIUS_ALIASES = [:ConstraintRadius, :constraint_radius, :Radius, :radius, :ConstraintDiameter, :constraint_diameter, :Diameter, :diameter]
const _CONSTRAINT_SECONDARY_RADIUS_ALIASES = [:ConstraintSecondaryRadius, :constraint_secondary_radius, :SecondaryRadius, :secondary_radius, :SecondaryDiameter, :secondary_diameter]
const _CONSTRAINT_LENGTH_ALIASES = [:ConstraintLength, :constraint_length, :ConeLength, :cone_length]
const _CONSTRAINT_PLANE_D_ALIASES = [:ConstraintPlaneD, :constraint_plane_d, :PlaneD, :plane_d, :ConstraintD, :constraint_d]
const _CONSTRAINT_NORMAL_X_ALIASES = [:ConstraintNormalX, :constraint_normal_x, :PlaneNormalX, :plane_normal_x, :NormalX, :normal_x]
const _CONSTRAINT_NORMAL_Y_ALIASES = [:ConstraintNormalY, :constraint_normal_y, :PlaneNormalY, :plane_normal_y, :NormalY, :normal_y]
const _CONSTRAINT_NORMAL_Z_ALIASES = [:ConstraintNormalZ, :constraint_normal_z, :PlaneNormalZ, :plane_normal_z, :NormalZ, :normal_z]
const _CONSTRAINT_ORIGIN_X_ALIASES = [:ConstraintOriginX, :constraint_origin_x, :ConstraintVertexX, :constraint_vertex_x, :OriginX, :origin_x, :VertexX, :vertex_x]
const _CONSTRAINT_ORIGIN_Y_ALIASES = [:ConstraintOriginY, :constraint_origin_y, :ConstraintVertexY, :constraint_vertex_y, :OriginY, :origin_y, :VertexY, :vertex_y]
const _CONSTRAINT_ORIGIN_Z_ALIASES = [:ConstraintOriginZ, :constraint_origin_z, :ConstraintVertexZ, :constraint_vertex_z, :OriginZ, :origin_z, :VertexZ, :vertex_z]
const _CONSTRAINT_AXIS_X_ALIASES = [:ConstraintAxisX, :constraint_axis_x, :ConstraintDirectionX, :constraint_direction_x, :AxisX, :axis_x, :DirectionX, :direction_x]
const _CONSTRAINT_AXIS_Y_ALIASES = [:ConstraintAxisY, :constraint_axis_y, :ConstraintDirectionY, :constraint_direction_y, :AxisY, :axis_y, :DirectionY, :direction_y]
const _CONSTRAINT_AXIS_Z_ALIASES = [:ConstraintAxisZ, :constraint_axis_z, :ConstraintDirectionZ, :constraint_direction_z, :AxisZ, :axis_z, :DirectionZ, :direction_z]

function _constraint_kind(value)
    value === nothing && return nothing
    s = lowercase(replace(string(value), r"[^a-z0-9]+" => ""))

    s in ("cone",) && return :cone
    s in ("ellipticcone", "ellipticalcone") && return :elliptic_cone
    s in ("cylinder",) && return :cylinder
    s in ("ellipticcylinder", "ellipticalcylinder") && return :elliptic_cylinder
    s in ("conecylinder", "coneandcylinder", "cylcone") && return :cone_cylinder
    s in ("ellipticconecylinder", "ellipticalconecylinder", "ellipticconeandcylinder") &&
        return :elliptic_cone_cylinder
    s in ("plane",) && return :plane
    return nothing
end

@inline function _constraint_float_from_source(source, names::Vector{Symbol})
    source === nothing && return nothing
    for name in names
        value = _field_or_key(source, name, nothing)
        f = _as_float(value)
        f !== nothing && return f
    end
    return nothing
end

@inline function _constraint_float_from_node(node, aliases::Vector{Symbol})
    value, found = _resolve_alias(node, aliases)
    return found === nothing ? nothing : value
end

function _as_vec3(value)
    value === nothing && return nothing
    value === missing && return nothing

    if value isa Tuple && length(value) == 3
        x = _as_float(value[1])
        y = _as_float(value[2])
        z = _as_float(value[3])
        return (x === nothing || y === nothing || z === nothing) ? nothing : SVector{3,Float64}(x, y, z)
    end

    if value isa AbstractVector && length(value) == 3
        x = _as_float(value[1])
        y = _as_float(value[2])
        z = _as_float(value[3])
        return (x === nothing || y === nothing || z === nothing) ? nothing : SVector{3,Float64}(x, y, z)
    end

    if value isa AbstractDict || value isa NamedTuple
        x = _as_float(_field_or_key(value, :x, nothing))
        y = _as_float(_field_or_key(value, :y, nothing))
        z = _as_float(_field_or_key(value, :z, nothing))
        return (x === nothing || y === nothing || z === nothing) ? nothing : SVector{3,Float64}(x, y, z)
    end

    if hasproperty(value, :x) && hasproperty(value, :y) && hasproperty(value, :z)
        x = _as_float(getproperty(value, :x))
        y = _as_float(getproperty(value, :y))
        z = _as_float(getproperty(value, :z))
        return (x === nothing || y === nothing || z === nothing) ? nothing : SVector{3,Float64}(x, y, z)
    end

    return nothing
end

function _constraint_vec3_from_components(source, xnames::Vector{Symbol}, ynames::Vector{Symbol}, znames::Vector{Symbol})
    source === nothing && return nothing
    x = _constraint_float_from_source(source, xnames)
    y = _constraint_float_from_source(source, ynames)
    z = _constraint_float_from_source(source, znames)
    return (x === nothing || y === nothing || z === nothing) ? nothing : SVector{3,Float64}(x, y, z)
end

function _constraint_vec3_from_node(node, xaliases::Vector{Symbol}, yaliases::Vector{Symbol}, zaliases::Vector{Symbol})
    x = _constraint_float_from_node(node, xaliases)
    y = _constraint_float_from_node(node, yaliases)
    z = _constraint_float_from_node(node, zaliases)
    return (x === nothing || y === nothing || z === nothing) ? nothing : SVector{3,Float64}(x, y, z)
end

function _resolve_geometry_constraint_spec(node, options::AmapReconstructionOptions)
    raw_constraint, _ = _resolve_raw_alias(node, options.geometry_constraint_aliases)

    raw_type = if raw_constraint !== nothing
        _field_or_key(raw_constraint, :type, _field_or_key(raw_constraint, :kind, nothing))
    else
        nothing
    end
    if raw_type === nothing
        raw_type, _ = _resolve_raw_alias(node, _CONSTRAINT_TYPE_ALIASES)
    end
    if raw_type === nothing && (raw_constraint isa Symbol || raw_constraint isa AbstractString)
        raw_type = raw_constraint
    end

    kind = _constraint_kind(raw_type)
    kind === nothing && return nothing

    primary_angle = _constraint_float_from_source(raw_constraint, [:primary_angle, :primaryangle, :angle, :primaryAngle])
    primary_angle === nothing && (primary_angle = _constraint_float_from_node(node, _CONSTRAINT_PRIMARY_ANGLE_ALIASES))
    primary_angle === nothing && (primary_angle = 30.0)

    secondary_angle = _constraint_float_from_source(raw_constraint, [:secondary_angle, :secondaryangle, :secondaryAngle])
    secondary_angle === nothing && (secondary_angle = _constraint_float_from_node(node, _CONSTRAINT_SECONDARY_ANGLE_ALIASES))
    secondary_angle === nothing && (secondary_angle = primary_angle)

    radius = _constraint_float_from_source(raw_constraint, [:radius, :diameter, :primary_radius, :primary_diameter])
    radius === nothing && (radius = _constraint_float_from_node(node, _CONSTRAINT_RADIUS_ALIASES))
    radius === nothing && (radius = 1.0)

    secondary_radius = _constraint_float_from_source(raw_constraint, [:secondary_radius, :secondary_diameter])
    secondary_radius === nothing && (secondary_radius = _constraint_float_from_node(node, _CONSTRAINT_SECONDARY_RADIUS_ALIASES))
    secondary_radius === nothing && (secondary_radius = radius)

    cone_length = _constraint_float_from_source(raw_constraint, [:cone_length, :length, :transition_length])
    cone_length === nothing && (cone_length = _constraint_float_from_node(node, _CONSTRAINT_LENGTH_ALIASES))
    cone_length === nothing && (cone_length = 1.0)

    plane_normal = _as_vec3(_field_or_key(raw_constraint, :normal, _field_or_key(raw_constraint, :plane_normal, nothing)))
    if plane_normal === nothing
        plane_normal = _constraint_vec3_from_components(
            raw_constraint,
            [:normal_x, :plane_normal_x, :nx],
            [:normal_y, :plane_normal_y, :ny],
            [:normal_z, :plane_normal_z, :nz],
        )
    end
    plane_normal === nothing && (plane_normal = _constraint_vec3_from_node(node, _CONSTRAINT_NORMAL_X_ALIASES, _CONSTRAINT_NORMAL_Y_ALIASES, _CONSTRAINT_NORMAL_Z_ALIASES))
    plane_normal === nothing && (plane_normal = _UP3)
    plane_normal = _safe_normalize(plane_normal, _UP3)

    plane_d = _constraint_float_from_source(raw_constraint, [:d, :plane_d])
    plane_d === nothing && (plane_d = _constraint_float_from_node(node, _CONSTRAINT_PLANE_D_ALIASES))
    plane_d === nothing && (plane_d = 0.0)

    origin = _as_vec3(_field_or_key(raw_constraint, :origin, _field_or_key(raw_constraint, :vertex, nothing)))
    if origin === nothing
        origin = _constraint_vec3_from_components(
            raw_constraint,
            [:origin_x, :vertex_x],
            [:origin_y, :vertex_y],
            [:origin_z, :vertex_z],
        )
    end
    origin === nothing && (origin = _constraint_vec3_from_node(node, _CONSTRAINT_ORIGIN_X_ALIASES, _CONSTRAINT_ORIGIN_Y_ALIASES, _CONSTRAINT_ORIGIN_Z_ALIASES))

    axis = _as_vec3(_field_or_key(raw_constraint, :axis, _field_or_key(raw_constraint, :direction, nothing)))
    if axis === nothing
        axis = _constraint_vec3_from_components(
            raw_constraint,
            [:axis_x, :direction_x],
            [:axis_y, :direction_y],
            [:axis_z, :direction_z],
        )
    end
    axis === nothing && (axis = _constraint_vec3_from_node(node, _CONSTRAINT_AXIS_X_ALIASES, _CONSTRAINT_AXIS_Y_ALIASES, _CONSTRAINT_AXIS_Z_ALIASES))

    return (
        raw=raw_constraint,
        kind=kind,
        primary_angle=primary_angle,
        secondary_angle=secondary_angle,
        radius=radius,
        secondary_radius=secondary_radius,
        cone_length=cone_length,
        plane_normal=plane_normal,
        plane_d=plane_d,
        origin=origin,
        axis=axis,
    )
end

function _constraint_frame!(
    cache::Dict{Any,Any},
    key,
    spec,
    base_pos::SVector{3,Float64},
    rot::SMatrix{3,3,Float64,9},
    length_axis::Symbol,
)
    if haskey(cache, key)
        return cache[key]
    end

    axis = spec.axis === nothing ? _axis_column(rot, length_axis) : _safe_normalize(spec.axis, _axis_column(rot, length_axis))
    secondary = _normalize_perpendicular(
        _axis_column(rot, _secondary_axis(length_axis)),
        axis,
        _any_perpendicular(axis, _unit_axis(_secondary_axis(length_axis))),
    )
    normal = _normalize_perpendicular(cross(axis, secondary), axis, _any_perpendicular(axis, _UP3))
    origin = spec.origin === nothing ? base_pos : spec.origin

    frame = (origin=origin, axis=axis, secondary=secondary, normal=normal)
    cache[key] = frame
    return frame
end

function _constraint_clamp_elliptic(x::Float64, y::Float64, a::Float64, b::Float64)
    aa = max(abs(a), 1e-12)
    bb = max(abs(b), 1e-12)
    e = (x / aa)^2 + (y / bb)^2
    if e <= 1.0
        return x, y, false
    end
    scale = inv(sqrt(e))
    return x * scale, y * scale, true
end

function _constraint_allowed_radii(spec, h::Float64)
    if spec.kind in (:cylinder, :elliptic_cylinder)
        return spec.radius, spec.secondary_radius
    elseif spec.kind in (:cone, :elliptic_cone)
        h <= 0.0 && return nothing
        return h * tan(deg2rad(spec.primary_angle)), h * tan(deg2rad(spec.secondary_angle))
    elseif spec.kind in (:cone_cylinder, :elliptic_cone_cylinder)
        h <= 0.0 && return nothing
        hh = min(h, max(spec.cone_length, 1e-12))
        return hh * tan(deg2rad(spec.primary_angle)), hh * tan(deg2rad(spec.secondary_angle))
    end
    return nothing
end

function _constrain_tip_by_geometry(
    base_pos::SVector{3,Float64},
    tip::SVector{3,Float64},
    frame,
    spec,
)
    rel = tip - frame.origin
    h = dot(rel, frame.axis)
    h <= 0.0 && return base_pos + frame.axis

    radial = rel - h * frame.axis
    x = dot(radial, frame.secondary)
    y = dot(radial, frame.normal)
    radii = _constraint_allowed_radii(spec, h)
    radii === nothing && return base_pos + frame.axis

    x2, y2, clamped = _constraint_clamp_elliptic(x, y, radii[1], radii[2])
    clamped || return nothing
    return frame.origin + h * frame.axis + x2 * frame.secondary + y2 * frame.normal
end

function _constrain_direction_to_plane(
    base_pos::SVector{3,Float64},
    current_dir::SVector{3,Float64},
    frame,
    spec,
)
    signed_distance = dot(spec.plane_normal, base_pos) + spec.plane_d
    signed_distance > 0.0 || return nothing

    projected = current_dir - dot(current_dir, spec.plane_normal) * spec.plane_normal
    fallback = _any_perpendicular(spec.plane_normal, frame.secondary)
    return _safe_normalize(projected, fallback)
end

function _apply_geometry_constraint_stage(
    node,
    rot::SMatrix{3,3,Float64,9},
    base_pos::SVector{3,Float64},
    length_axis::Symbol,
    length_val::Float64,
    options::AmapReconstructionOptions,
    constraint_cache::Dict{Any,Any},
)
    length_val <= 0.0 && return rot

    spec = _resolve_geometry_constraint_spec(node, options)
    spec === nothing && return rot

    key = spec.raw === nothing ? (spec.kind, node) : spec.raw
    frame = _constraint_frame!(constraint_cache, key, spec, base_pos, rot, length_axis)
    current_dir = _safe_normalize(rot * _unit_axis(length_axis), frame.axis)

    new_dir = if spec.kind == :plane
        _constrain_direction_to_plane(base_pos, current_dir, frame, spec)
    else
        tip = base_pos + current_dir * length_val
        target_tip = _constrain_tip_by_geometry(base_pos, tip, frame, spec)
        target_tip === nothing ? nothing : _safe_normalize(target_tip - base_pos, current_dir)
    end

    new_dir === nothing && return rot
    if dot(new_dir, current_dir) <= 0.0
        new_dir = frame.axis
    end

    return _rotation_from_direction_with_hint(new_dir, length_axis, rot)
end

function _young_final_angle(
    young_modulus::Float64,
    z_angle::Float64,
    length::Float64,
    tapering::Float64,
)
    if young_modulus <= 0.0 || length <= 0.0
        return z_angle
    end

    cos_theta = cos(z_angle)
    young = 1.0 / sqrt(young_modulus)
    h = length / max(abs(tapering), 1e-6)
    coeff = young * h * sqrt(abs(cos_theta))

    deflexion = if z_angle > 1.553 && z_angle < 1.588
        young * young * h * h / 2.0
    else
        denom = cos(coeff) * max(abs(cos_theta), 1e-8)
        abs(denom) <= 1e-10 ? 0.0 : (sin(z_angle) * (1.0 - cos(coeff)) / denom)
    end

    amin = 0.0
    amax = max(0.0, pi - z_angle)
    threshold = pi / 180.0
    precision = max(length / 10.0, 1e-6)

    while (amax - amin) > threshold
        deflexion = (amax + amin) / 2.0
        omega = 0.0
        sum_v = 0.0
        increment = 1.0
        nbiter = 0
        while omega < deflexion && increment != 0.0 && nbiter < 500
            term = abs(cos(z_angle + omega) - cos(z_angle + deflexion))
            increment = precision * sqrt(2.0) * young * sqrt(term)
            omega += increment
            sum_v += precision
            nbiter += 1
        end
        if sum_v <= (h - precision)
            amin = deflexion
        else
            amax = deflexion
        end
    end

    ((amin + amax) / 2.0) + z_angle
end

function _young_local_flexion(
    current_angle::Float64,
    final_angle::Float64,
    young_modulus::Float64,
    tapering::Float64,
    relative_position::Float64,
)
    angle = 2.0 * (cos(current_angle) - cos(final_angle))
    angle < 0.0 && return 0.0

    aux = 1.0 - ((1.0 - tapering) * relative_position)
    aux2 = aux * aux
    aux2 <= 1e-12 && return 0.0

    flre = 1.0 / (sqrt(young_modulus) * aux2)
    flre * sqrt(angle)
end

function _resolve_stiffness_straightening(node, options::AmapReconstructionOptions)
    value, found = _resolve_alias(node, options.stiffness_straightening_aliases)
    if found === nothing || value === nothing
        return nothing
    end
    # Accept both [0, 1] and [0, 100] conventions.
    straightening = value > 1.0 ? (value / 100.0) : value
    return clamp(straightening, 0.0, 1.0)
end

function _apply_broken_to_components!(node, components_nodes, target_name::Symbol, options::AmapReconstructionOptions)
    broken_pos, broken_found = _resolve_alias(node, options.broken_aliases)
    if broken_found === nothing || broken_pos === nothing || isempty(components_nodes)
        return false
    end

    nb = length(components_nodes)
    step = 100.0 / nb
    applied = false
    for (idx, component_node) in enumerate(components_nodes)
        pos_pct = ((idx - 1) / nb) * 100.0
        if pos_pct + step > broken_pos
            component_node[target_name] = -180.0
            applied = true
        end
    end
    return applied
end

function _successor_anchor_node(parent_node, top_pos)
    anchor = parent_node
    for child in children(parent_node)
        link(child) == :/ || continue
        haskey(top_pos, child) || continue
        anchor = child
    end
    return anchor
end

function _propagate_stiffness_to_components!(
    node,
    rot::SMatrix{3,3,Float64,9},
    length_axis::Symbol,
    node_length::Float64,
    options::AmapReconstructionOptions,
)
    components_nodes = _component_children(node)
    isempty(components_nodes) && return

    target_name = isempty(options.stiffness_angle_aliases) ? :StiffnessAngle : first(options.stiffness_angle_aliases)
    broken_applied = false

    if !_resolve_bool_alias(node, options.stiffness_apply_aliases; default=true)
        _apply_broken_to_components!(node, components_nodes, target_name, options)
        return
    end

    stiff_value, stiff_found = _resolve_alias(node, options.stiffness_aliases)
    if stiff_found === nothing || stiff_value === nothing || stiff_value == 0.0 || node_length <= 0.0
        _apply_broken_to_components!(node, components_nodes, target_name, options)
        return
    end

    tapering_value, tapering_found = _resolve_alias(node, options.stiffness_tapering_aliases)
    tapering = (tapering_found !== nothing && tapering_value !== nothing) ? tapering_value : 0.5
    straightening = _resolve_stiffness_straightening(node, options)

    is_down = stiff_value > 0.0
    young_modulus = abs(stiff_value)
    if young_modulus <= 0.0
        _apply_broken_to_components!(node, components_nodes, target_name, options)
        return
    end

    direction = _safe_normalize(rot * _unit_axis(length_axis), _unit_axis(length_axis))
    z_angle = acos(clamp(direction[3], -1.0, 1.0))
    final_angle = _young_final_angle(young_modulus, z_angle, node_length, tapering)

    current_angle = z_angle
    previous_angle = current_angle
    current_distance_from_insertion = 0.0
    prev_position_in_portee = 0
    n_components = length(components_nodes)

    for component_node in components_nodes
        relative_position_in_portee = floor(Int, (node_length * current_distance_from_insertion) / n_components)

        for i in prev_position_in_portee:(relative_position_in_portee-1)
            relative_position = i / node_length
            local_angle = _young_local_flexion(
                current_angle,
                final_angle,
                young_modulus,
                tapering,
                relative_position,
            )

            if straightening !== nothing && straightening < 1.0 && relative_position > straightening
                t = (relative_position - straightening) / max(1.0 - straightening, 1e-12)
                local_angle *= max(0.0, 1.0 - t)
            end

            current_angle += local_angle
        end

        propagated_angle = rad2deg(current_angle - previous_angle)
        component_node[target_name] = is_down ? -propagated_angle : propagated_angle

        prev_position_in_portee = relative_position_in_portee
        previous_angle = current_angle
        current_distance_from_insertion += 1.0
    end

    broken_applied = _apply_broken_to_components!(node, components_nodes, target_name, options)
    broken_applied
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
        ref_mesh_selector=nothing,
        dUp=1.0,
        dDwn=1.0,
        warn_missing=false,
        root_align=true,
    )

Reconstruct node geometries from attribute conventions and MTG topology.

When no explicit translation attributes are found (`XX/YY/ZZ` by default), placement follows a
topological convention close to AMAP:

- `:<`: attach to predecessor top
- `:+`: attach to bearer at `Offset` (or bearer length if missing)
- `:+`: default insertion mode is `BORDER`, adding a lateral offset of
  `BorderInsertionOffset` (or bearer top width / 2)
- `:/`: attach to parent base

If endpoint attributes (`EndX`/`EndY`/`EndZ` aliases) are present, they override angle-derived
orientation and `Length` for that node: base position comes from translation/topology, and
orientation+length are inferred from `(base -> end)`.
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
    ref_mesh_selector::Union{Nothing,Function}=nothing,
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
    effective_phyllotaxy_aliases = _compose_aliases(amap_cfg.phyllotaxy_aliases, phyllotaxy_aliases_norm)
    effective_verticil_mode = verticil_mode_norm == :rotation360 ? amap_cfg.verticil_mode : verticil_mode_norm
    coordinate_mode = _coordinate_delegate_mode(amap_cfg.coordinate_delegate_mode)

    if amap_cfg.auto_compute_branching_order &&
       !_mtg_has_numeric_attribute(mtg, amap_cfg.order_attribute)
        MultiScaleTreeGraph.branching_order!(mtg; ascend=true)
    end

    _prepare_amap_allometry!(mtg, convention, conventions, amap_cfg)

    root_rotation = if root_align && convention.length_axis == :x
        SMatrix{3,3,Float64}(RotMatrix(AngleAxis(-pi / 2, 0.0, 1.0, 0.0)))
    else
        _I3
    end

    base_pos = IdDict{Any,SVector{3,Float64}}()
    top_pos = IdDict{Any,SVector{3,Float64}}()
    direction = IdDict{Any,SVector{3,Float64}}()
    base_rot = IdDict{Any,SMatrix{3,3,Float64,9}}()
    constraint_cache = Dict{Any,Any}()

    traverse!(mtg) do node
        node_convention = _resolve_node_convention(node, convention, conventions)
        conv_insertion_only = _convention_insertion_angles_only(node_convention)

        explicit_translation = _has_explicit_translation(node, node_convention)

        parent_node = isroot(node) ? nothing : parent(node)
        link_type = isroot(node) ? nothing : link(node)

        current_base_rot = root_rotation
        current_base_pos = _ZERO3

        if !explicit_translation && parent_node !== nothing
            if link_type == :<
                anchor_node = _successor_anchor_node(parent_node, top_pos)
                if haskey(base_rot, anchor_node)
                    current_base_rot = base_rot[anchor_node]
                    current_base_pos = get(top_pos, anchor_node, _ZERO3)
                elseif haskey(base_rot, parent_node)
                    current_base_rot = base_rot[parent_node]
                    current_base_pos = get(top_pos, parent_node, _ZERO3)
                end
            elseif link_type == :+
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
            elseif link_type == :/
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

        delegate2_current = false
        if coordinate_mode == :explicit_rewire_previous && explicit_translation
            delegate2_current = true

            if link_type == :/ && parent_node !== nothing && haskey(base_pos, parent_node)
                # CoordinateDelegate2 behavior: decomposition child is anchored
                # at complex base position (not at explicit coordinate).
                current_base_pos = get(base_pos, parent_node, current_base_pos)
            else
                prev_node = _coordinate_delegate2_previous_node(parent_node, link_type)
                if prev_node !== nothing
                    _apply_coordinate_delegate2_previous!(
                        prev_node,
                        current_base_pos,
                        convention,
                        conventions,
                        ref_meshes,
                        ref_mesh_selector,
                        base_pos,
                        top_pos,
                        direction,
                        base_rot;
                        dUp=dUp,
                        dDwn=dDwn,
                        warn_missing=warn_missing,
                    )
                end
            end
        end

        endpoint_pos = _resolve_endpoint_position(node, amap_cfg; warn_missing=warn_missing)
        endpoint_override = false
        endpoint_length = nothing
        if coordinate_mode == :explicit_start_end_required && explicit_translation && endpoint_pos === nothing
            # CoordinateDelegate3 strict mode: explicit start without explicit end
            # yields an undefined segment geometry for this node.
            warn_missing &&
                @warn "Explicit translation without complete EndX/EndY/EndZ in :explicit_start_end_required mode; skipping node geometry."
            p0 = current_base_pos
            p1 = current_base_pos
            r0 = current_base_rot
            d0 = _normalize_direction(p1 - p0, r0, node_convention.length_axis)

            base_pos[node] = p0
            top_pos[node] = p1
            direction[node] = d0
            base_rot[node] = r0
            node[:geometry] = nothing
            return
        elseif !delegate2_current && endpoint_pos !== nothing
            endpoint_vec = endpoint_pos - current_base_pos
            endpoint_length_val = norm(endpoint_vec)
            if endpoint_length_val > 1e-12
                current_base_rot = _rotation_from_direction_with_hint(
                    endpoint_vec,
                    node_convention.length_axis,
                    current_base_rot,
                )
                endpoint_override = true
                endpoint_length = endpoint_length_val
            else
                warn_missing && @warn "Degenerate endpoint (base == end) ignored for node."
            end
        end

        order_value = _resolve_order_value(node, amap_cfg.order_attribute)
        insertion_y_override = _effective_override_value(order_value, amap_cfg.insertion_y_by_order)
        phyllotaxy_override = _effective_override_value(order_value, amap_cfg.phyllotaxy_by_order)

        override_by_axis = Dict{Symbol,Float64}()
        if insertion_y_override !== nothing
            override_by_axis[:y] = insertion_y_override
        end

        local_insertion_t = endpoint_override ? IdentityTransformation() : _angles_transform(
            node,
            conv_insertion_only.angle_map;
            warn_missing=warn_missing,
            override_axis_deg=override_by_axis,
            override_mode=amap_cfg.order_override_mode,
        )
        local_euler_t = endpoint_override ? IdentityTransformation() :
                        transformation_from_attributes(node; convention=conv_euler_only, warn_missing=warn_missing)

        if !endpoint_override && link_type == :+ && parent_node !== nothing
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
                # Keep fallback XInsertionAngle in the same stage/order as insertion angles.
                # Appending on the right applies it first and can cancel azimuth spread.
                local_insertion_t = _rotation_linear_map(:x, deg2rad(extra_x_deg)) ∘ local_insertion_t
            end
        end

        base_t = _frame_transform(current_base_rot, current_base_pos)

        if !endpoint_override && !explicit_translation &&
           link_type == :+ && parent_node !== nothing && haskey(base_rot, parent_node)
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

        length_val, width_val, thickness_val = _resolve_scale_values(
            node,
            node_convention;
            warn_missing=warn_missing,
            length_override=endpoint_length,
        )

        rot = if delegate2_current
            _I3
        elseif endpoint_override
            current_base_rot
        else
            r = _rotation_part(base_t ∘ local_insertion_t)
            r = _apply_azimuth_elevation_stage(node, r, amap_cfg)
            r = _apply_orthotropy_stiffness_stage(node, r, node_convention.length_axis, amap_cfg)
            r = _apply_deviation_stage(node, r, amap_cfg)
            r = r * _rotation_part(local_euler_t)
            r = _apply_projection_stage(node, r, node_convention.length_axis, amap_cfg)
            _apply_geometry_constraint_stage(
                node,
                r,
                current_base_pos,
                node_convention.length_axis,
                length_val,
                amap_cfg,
                constraint_cache,
            )
        end

        if delegate2_current
            length_val = 0.0
        end

        lin = rot * _scale_linear(node_convention.length_axis, length_val, width_val, thickness_val)
        world_t = AffineMap(Matrix(lin), current_base_pos)
        world_angles_t = AffineMap(Matrix(rot), current_base_pos)

        p0 = _to_svec3(world_t(_ZERO3))
        p1 = _to_svec3(world_t(_unit_axis(node_convention.length_axis)))
        if endpoint_override
            p0 = current_base_pos
            p1 = endpoint_pos
        end
        rot = _rotation_part(world_angles_t)
        dir = _normalize_direction(p1 - p0, rot, node_convention.length_axis)

        base_pos[node] = p0
        top_pos[node] = p1
        direction[node] = dir
        base_rot[node] = rot

        _propagate_stiffness_to_components!(
            node,
            rot,
            node_convention.length_axis,
            norm(p1 - p0),
            amap_cfg,
        )

        ref_mesh = _resolve_ref_mesh(node, ref_meshes, ref_mesh_selector)
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
    ref_mesh_selector::Union{Nothing,Function}=nothing,
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
        ref_mesh_selector=ref_mesh_selector,
        dUp=dUp,
        dDwn=dDwn,
        warn_missing=warn_missing,
        root_align=root_align,
    )
end
