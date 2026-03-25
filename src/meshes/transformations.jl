"""
    final_angle(young_modulus, z_angle, beam_length, tapering;
        length_scale=100.0, threshold=π / 180.0, max_iter=500)

Calculate the maximal deformation angle of a cantilever beam.

`z_angle` is the initial angle from vertical (radians). `beam_length` is scaled
by `length_scale` before evaluation to support legacy formulations expressed in
centimeters (`length_scale=100.0` when length is provided in meters).
"""
function final_angle(
    young_modulus::Real,
    z_angle::Real,
    beam_length::Real,
    tapering::Real;
    length_scale::Real=100.0,
    threshold::Real=π / 180.0,
    max_iter::Integer=500,
)
    young_modulus_f = Float64(young_modulus)
    z_angle_f = Float64(z_angle)
    beam_length_f = Float64(beam_length) * Float64(length_scale)
    tapering_f = Float64(tapering)

    if young_modulus_f <= 0.0 || beam_length_f <= 0.0
        return z_angle_f
    end

    cos_theta = cos(z_angle_f)
    young = 1.0 / sqrt(young_modulus_f)
    h = beam_length_f / max(abs(tapering_f), 1e-6)
    coeff = young * h * sqrt(abs(cos_theta))

    deflection = if z_angle_f > 1.553 && z_angle_f < 1.588
        young * young * h * h / 2.0
    else
        denom = cos(coeff) * max(abs(cos_theta), 1e-8)
        abs(denom) <= 1e-10 ? 0.0 : (sin(z_angle_f) * (1.0 - cos(coeff)) / denom)
    end

    a_min = 0.0
    a_max = max(0.0, π - z_angle_f)
    threshold_f = max(Float64(threshold), 1e-8)
    precision = max(beam_length_f / 10.0, 1e-6)
    max_iter_i = max(Int(max_iter), 1)

    while (a_max - a_min) > threshold_f
        deflection = (a_max + a_min) / 2.0
        omega = 0.0
        sum_v = 0.0
        increment = 1.0
        nb_iter = 0

        while omega < deflection && increment != 0.0 && nb_iter < max_iter_i
            term = abs(cos(z_angle_f + omega) - cos(z_angle_f + deflection))
            increment = precision * sqrt(2.0) * young * sqrt(term)
            omega += increment
            sum_v += precision
            nb_iter += 1
        end

        if sum_v <= (h - precision)
            a_min = deflection
        else
            a_max = deflection
        end
    end

    ((a_min + a_max) / 2.0) + z_angle_f
end

"""
    local_flexion(current_angle, final_angle, young_modulus, tapering, relative_position)

Calculate the local bending angle increment at a relative beam position.
Angles are in radians and `relative_position` is expected in `[0, 1]`.
"""
function local_flexion(
    current_angle::Real,
    final_angle::Real,
    young_modulus::Real,
    tapering::Real,
    relative_position::Real,
)
    young_modulus_f = Float64(young_modulus)
    young_modulus_f <= 0.0 && return 0.0

    angle = 2.0 * (cos(Float64(current_angle)) - cos(Float64(final_angle)))
    angle < 0.0 && return 0.0

    aux = 1.0 - ((1.0 - Float64(tapering)) * Float64(relative_position))
    aux2 = aux * aux
    aux2 <= 1e-12 && return 0.0

    fl_re = 1.0 / (sqrt(young_modulus_f) * aux2)
    fl_re * sqrt(angle)
end

"""
    calculate_segment_angles(young_modulus, initial_angle, beam_length, tapering, segment_positions;
        length_scale=100.0, integration_steps=10)

Calculate global angles (radians) at each segment boundary position according to
the Young's-modulus bending model.
"""
function calculate_segment_angles(
    young_modulus::Real,
    initial_angle::Real,
    beam_length::Real,
    tapering::Real,
    segment_positions::AbstractVector{<:Real};
    length_scale::Real=100.0,
    integration_steps::Integer=10,
)
    n_positions = length(segment_positions)
    n_positions > 1 || error("`segment_positions` must contain at least 2 values.")
    n_steps = Int(integration_steps)
    n_steps >= 1 || error("`integration_steps` must be >= 1.")

    first_pos = Float64(segment_positions[1])
    last_pos = Float64(segment_positions[end])
    span = last_pos - first_pos
    span > 0.0 || error("`segment_positions` must be strictly increasing.")

    normalized_positions = Vector{Float64}(undef, n_positions)
    normalized_positions[1] = 0.0
    prev_raw = first_pos
    @inbounds for i in 2:n_positions
        current_raw = Float64(segment_positions[i])
        current_raw > prev_raw || error("`segment_positions` must be strictly increasing.")
        normalized_positions[i] = (current_raw - first_pos) / span
        prev_raw = current_raw
    end

    total_deflection = final_angle(
        young_modulus,
        initial_angle,
        beam_length,
        tapering;
        length_scale=length_scale,
    )

    boundary_angles = Vector{Float64}(undef, n_positions)
    boundary_angles[1] = Float64(initial_angle)

    @inbounds for i in 2:n_positions
        relative_pos = normalized_positions[i]
        prev_pos = normalized_positions[i - 1]
        current_angle = boundary_angles[i - 1]

        flexion = 0.0
        step_size = (relative_pos - prev_pos) / n_steps
        step_pos = prev_pos
        for _ in 1:n_steps
            step_pos += step_size
            flexion += local_flexion(
                current_angle + flexion,
                total_deflection,
                young_modulus,
                tapering,
                step_pos,
            )
        end

        boundary_angles[i] = current_angle + flexion
    end

    boundary_angles
end

"""
    update_segment_angles!(
        segment_nodes,
        young_modulus,
        initial_angle,
        beam_length,
        tapering;
        segment_positions=nothing,
        angle_key=:zenithal_angle,
        mode=:absolute,
        degrees=true,
        length_scale=100.0,
        integration_steps=10,
    )

Update angle attributes on an ordered chain of segment nodes.

`segment_nodes` must be ordered from base to tip. By default, `mode=:absolute`
writes the cumulative zenith angle at each segment boundary. With
`mode=:incremental`, written values are local increments between boundaries.

Returns the computed absolute boundary angles in radians.
"""
function update_segment_angles!(
    segment_nodes::AbstractVector,
    young_modulus::Real,
    initial_angle::Real,
    beam_length::Real,
    tapering::Real;
    segment_positions::Union{Nothing,AbstractVector{<:Real}}=nothing,
    angle_key::Symbol=:zenithal_angle,
    mode::Symbol=:absolute,
    degrees::Bool=true,
    length_scale::Real=100.0,
    integration_steps::Integer=10,
)
    n_segments = length(segment_nodes)
    n_segments == 0 && return Float64[]

    positions = if segment_positions === nothing
        collect(range(0.0, 1.0; length=n_segments))
    else
        length(segment_positions) == n_segments ||
            error("`segment_positions` must have the same length as `segment_nodes`.")
        Float64.(collect(segment_positions))
    end

    boundary_angles = if n_segments == 1
        [Float64(initial_angle)]
    else
        calculate_segment_angles(
            young_modulus,
            initial_angle,
            beam_length,
            tapering,
            positions;
            length_scale=length_scale,
            integration_steps=integration_steps,
        )
    end

    values_rad = if mode == :absolute
        boundary_angles
    elseif mode == :incremental
        [boundary_angles[1]; diff(boundary_angles)]
    else
        error("`mode` must be `:absolute` or `:incremental`.")
    end

    factor = degrees ? (180.0 / π) : 1.0
    @inbounds for i in eachindex(segment_nodes)
        segment_nodes[i][angle_key] = values_rad[i] * factor
    end

    boundary_angles
end

"""
    update_segment_angles!(
        organ_node::MultiScaleTreeGraph.Node,
        young_modulus,
        initial_angle,
        beam_length,
        tapering;
        segment_symbol=:LeafletSegment,
        position_key=:segment_boundaries,
        require_positions=false,
        kwargs...,
    )

Convenience wrapper for segmented organs stored as consecutive MTG nodes.

It collects descendants matching `segment_symbol` (base-to-tip traversal order),
optionally reads their boundary positions from `position_key`, and delegates to
the vector-based [`update_segment_angles!`](@ref).
"""
function update_segment_angles!(
    organ_node::MultiScaleTreeGraph.Node,
    young_modulus::Real,
    initial_angle::Real,
    beam_length::Real,
    tapering::Real;
    segment_symbol=:LeafletSegment,
    position_key::Union{Nothing,Symbol}=:segment_boundaries,
    require_positions::Bool=false,
    kwargs...,
)
    segment_nodes = collect(descendants(organ_node, symbol=segment_symbol))
    isempty(segment_nodes) && return Float64[]

    segment_positions = nothing
    if position_key !== nothing
        values = descendants(organ_node, position_key; symbol=segment_symbol, ignore_nothing=true)
        if length(values) == length(segment_nodes) && all(v -> v isa Real, values)
            segment_positions = Float64.(values)
        elseif require_positions
            error("Could not resolve one numeric `$position_key` value per segment node.")
        end
    end

    update_segment_angles!(
        segment_nodes,
        young_modulus,
        initial_angle,
        beam_length,
        tapering;
        segment_positions=segment_positions,
        kwargs...,
    )
end

@inline _lerp_svec3(a::SVector{3,Float64}, b::SVector{3,Float64}, t::Float64) = a + t * (b - a)

function _frame_from_tangent(
    tangent::SVector{3,Float64},
    up::SVector{3,Float64},
)
    side = cross(up, tangent)
    if norm(side) <= 1e-8
        alt_up = abs(tangent[1]) < 0.9 ? SVector{3,Float64}(1.0, 0.0, 0.0) : SVector{3,Float64}(0.0, 1.0, 0.0)
        side = cross(alt_up, tangent)
    end
    side = _pointmap_safe_normalize(side, SVector{3,Float64}(0.0, 1.0, 0.0))
    normal = _pointmap_safe_normalize(cross(tangent, side), up)
    side, normal
end

"""
    BiomechanicalBendingTransform(young_modulus, initial_angle, beam_length, tapering;
        n_samples=96, integration_steps=10, x_min=0.0, x_max=beam_length,
        up=(0, 0, 1), length_scale=100.0)

Non-linear transformation based on a simplified cantilever biomechanical model.

The transform bends local coordinates along `+X` according to the angle profile
computed from [`final_angle`](@ref) and [`local_flexion`](@ref). It can be used
directly in [`Geometry`](@ref) or composed through [`transform_mesh!`](@ref).
`x_min`/`x_max` define how local `x` maps to the normalized `[0, 1]` profile.
"""
struct BiomechanicalBendingTransform <: Transformation
    centerline::Vector{SVector{3,Float64}}
    side::Vector{SVector{3,Float64}}
    normal::Vector{SVector{3,Float64}}
    x_min::Float64
    inv_x_span::Float64
    n_intervals::Int
end

function BiomechanicalBendingTransform(
    young_modulus::Real,
    initial_angle::Real,
    beam_length::Real,
    tapering::Real;
    n_samples::Integer=96,
    integration_steps::Integer=10,
    x_min::Real=0.0,
    x_max::Real=beam_length,
    up=(0.0, 0.0, 1.0),
    length_scale::Real=100.0,
)
    n_samples_i = Int(n_samples)
    n_samples_i >= 2 || error("`n_samples` must be >= 2.")

    segment_positions = collect(range(0.0, 1.0; length=n_samples_i))
    angles = calculate_segment_angles(
        young_modulus,
        initial_angle,
        beam_length,
        tapering,
        segment_positions;
        length_scale=length_scale,
        integration_steps=integration_steps,
    )

    beam_length_f = Float64(beam_length)
    centerline = Vector{SVector{3,Float64}}(undef, n_samples_i)
    tangents = Vector{SVector{3,Float64}}(undef, n_samples_i)
    centerline[1] = SVector{3,Float64}(0.0, 0.0, 0.0)
    tangents[1] = _pointmap_safe_normalize(
        SVector{3,Float64}(sin(angles[1]), 0.0, cos(angles[1])),
        SVector{3,Float64}(1.0, 0.0, 0.0),
    )

    @inbounds for i in 2:n_samples_i
        theta_prev = angles[i - 1]
        theta_curr = angles[i]
        theta_mid = 0.5 * (theta_prev + theta_curr)
        ds = beam_length_f * (segment_positions[i] - segment_positions[i - 1])
        centerline[i] = centerline[i - 1] + SVector{3,Float64}(ds * sin(theta_mid), 0.0, ds * cos(theta_mid))
        tangents[i] = _pointmap_safe_normalize(
            SVector{3,Float64}(sin(theta_curr), 0.0, cos(theta_curr)),
            tangents[i - 1],
        )
    end

    up_vec = _pointmap_safe_normalize(_svec3(up), SVector{3,Float64}(0.0, 0.0, 1.0))
    side = Vector{SVector{3,Float64}}(undef, n_samples_i)
    normal = Vector{SVector{3,Float64}}(undef, n_samples_i)
    @inbounds for i in 1:n_samples_i
        side[i], normal[i] = _frame_from_tangent(tangents[i], up_vec)
    end

    x_min_f = Float64(x_min)
    x_span = Float64(x_max) - x_min_f
    inv_x_span = abs(x_span) <= 1e-12 ? 1.0 : 1.0 / x_span

    BiomechanicalBendingTransform(
        centerline,
        side,
        normal,
        x_min_f,
        inv_x_span,
        n_samples_i - 1,
    )
end

function BiomechanicalBendingTransform(;
    young_modulus::Real,
    initial_angle::Real,
    beam_length::Real=1.0,
    tapering::Real=0.5,
    kwargs...,
)
    BiomechanicalBendingTransform(
        young_modulus,
        initial_angle,
        beam_length,
        tapering;
        kwargs...,
    )
end

function (transform::BiomechanicalBendingTransform)(p)
    q = _svec3(p)
    u = clamp((q[1] - transform.x_min) * transform.inv_x_span, 0.0, 1.0)
    scaled_u = u * transform.n_intervals
    idx = clamp(floor(Int, scaled_u) + 1, 1, transform.n_intervals)
    α = scaled_u - (idx - 1)

    center = _lerp_svec3(transform.centerline[idx], transform.centerline[idx + 1], α)
    side = _pointmap_safe_normalize(
        _lerp_svec3(transform.side[idx], transform.side[idx + 1], α),
        transform.side[idx],
    )
    normal = _pointmap_safe_normalize(
        _lerp_svec3(transform.normal[idx], transform.normal[idx + 1], α),
        transform.normal[idx],
    )

    center + q[2] * side + q[3] * normal
end

"""
    SequentialTransformation(outer, inner)

Transformation wrapper that preserves sequential application order (`outer ∘ inner`)
without collapsing to a single affine matrix in Float64.
"""
struct SequentialTransformation{TO<:Transformation,TI<:Transformation} <: Transformation
    outer::TO
    inner::TI
end

(t::SequentialTransformation)(x) = t.outer(t.inner(x))

@inline function _compose_transformation(outer::Transformation, inner::Transformation)
    if outer isa IdentityTransformation
        return inner
    elseif inner isa IdentityTransformation
        return outer
    else
        return SequentialTransformation(outer, inner)
    end
end

function _manual_transform_triplet(values::NTuple{3,<:Real}, label::AbstractString)
    SVector{3,Float64}(Float64(values[1]), Float64(values[2]), Float64(values[3]))
end

function _manual_transform_triplet(values::AbstractVector{<:Real}, label::AbstractString)
    length(values) == 3 || error("`$label` must have exactly 3 values, got $(length(values)).")
    SVector{3,Float64}(Float64(values[1]), Float64(values[2]), Float64(values[3]))
end

@inline function _manual_transform_triplet(values::StaticArrays.StaticVector{3,<:Real}, label::AbstractString)
    SVector{3,Float64}(Float64(values[1]), Float64(values[2]), Float64(values[3]))
end

@inline function _manual_transform_triplet(values::GeometryBasics.AbstractPoint{3}, label::AbstractString)
    SVector{3,Float64}(Float64(values[1]), Float64(values[2]), Float64(values[3]))
end

function _manual_scale_triplet(scale)
    if scale isa Real
        s = Float64(scale)
        return SVector{3,Float64}(s, s, s)
    end
    return _manual_transform_triplet(scale, "scale")
end

function _manual_rotation_triplet(rotate)
    if rotate isa NamedTuple
        return SVector{3,Float64}(
            Float64(get(rotate, :x, 0.0)),
            Float64(get(rotate, :y, 0.0)),
            Float64(get(rotate, :z, 0.0)),
        )
    elseif rotate === nothing
        return SVector{3,Float64}(0.0, 0.0, 0.0)
    end
    return _manual_transform_triplet(rotate, "rotate")
end

@inline _manual_angle_rad(angle::Real, deg::Bool) = deg ? deg2rad(Float64(angle)) : Float64(angle)

"""
    scale3(scale)
    scale3(sx, sy, sz)

Build a 3D scaling transformation for manual mesh placement.

`scale` can be either a scalar for uniform scaling or a 3-tuple / 3-vector for
anisotropic scaling.
"""
function scale3(scale)
    s = _manual_scale_triplet(scale)
    LinearMap(Diagonal(s))
end

function scale3(sx::Real, sy::Real, sz::Real)
    LinearMap(Diagonal(SVector{3,Float64}(Float64(sx), Float64(sy), Float64(sz))))
end

"""
    rotate_x(angle; deg=false)

Rotate around the local X axis.
"""
rotate_x(angle::Real; deg::Bool=false) = _rotation_linear_map(:x, _manual_angle_rad(angle, deg))

"""
    rotate_y(angle; deg=false)

Rotate around the local Y axis.
"""
rotate_y(angle::Real; deg::Bool=false) = _rotation_linear_map(:y, _manual_angle_rad(angle, deg))

"""
    rotate_z(angle; deg=false)

Rotate around the local Z axis.
"""
rotate_z(angle::Real; deg::Bool=false) = _rotation_linear_map(:z, _manual_angle_rad(angle, deg))

"""
    pose(; scale=1.0, rotate=(x=0.0, y=0.0, z=0.0), translate=(0.0, 0.0, 0.0), deg=false)

Build a manual affine transform for placing a mesh.

The returned transform always applies operations in this order:

1. scale
2. rotate around local X
3. rotate around local Y
4. rotate around local Z
5. translate

This helper is intended for hand-authored `RefMesh` placement where using
`LinearMap`, `AngleAxis`, and explicit composition would be unnecessarily low-level.

# Examples

```jldoctest
julia> t = pose(
           scale=(1.8, 1.0, 0.04),
           rotate=(y=30.0, z=12.0),
           translate=(2.0, 0.0, 1.4),
           deg=true,
       );

julia> round.(collect(t(PlantGeom.GeometryBasics.Point(1.0, 0.0, 0.0))); digits=3)
3-element Vector{Float64}:
 3.525
 0.324
 0.5
```
"""
function pose(;
    scale=1.0,
    rotate=(x=0.0, y=0.0, z=0.0),
    translate=(0.0, 0.0, 0.0),
    deg::Bool=false,
)
    scale_vals = _manual_scale_triplet(scale)
    rotate_vals = _manual_rotation_triplet(rotate)
    translate_vals = _manual_transform_triplet(translate, "translate")

    transformation = IdentityTransformation()

    if !(scale_vals[1] == 1.0 && scale_vals[2] == 1.0 && scale_vals[3] == 1.0)
        transformation = scale3(scale_vals)
    end

    if rotate_vals[1] != 0.0
        transformation = rotate_x(rotate_vals[1]; deg=deg) ∘ transformation
    end
    if rotate_vals[2] != 0.0
        transformation = rotate_y(rotate_vals[2]; deg=deg) ∘ transformation
    end
    if rotate_vals[3] != 0.0
        transformation = rotate_z(rotate_vals[3]; deg=deg) ∘ transformation
    end

    if !(translate_vals[1] == 0.0 && translate_vals[2] == 0.0 && translate_vals[3] == 0.0)
        transformation = Translation(translate_vals[1], translate_vals[2], translate_vals[3]) ∘ transformation
    end

    transformation
end

"""
    transform_mesh!(node::Node, transformation)

Add a new transformation to the node geometry `transformation` field.
The transformation is composed with the previous transformation if any.

`transformation` must be a `CoordinateTransformations.Transformation`.
"""
function transform_mesh!(node::MultiScaleTreeGraph.Node, transformation::Transformation)
    if has_geometry(node)
        geom = node[:geometry]
        if geom isa Geometry
            node[:geometry] = Geometry(
                ref_mesh=geom.ref_mesh,
                transformation=_compose_transformation(transformation, geom.transformation),
                dUp=geom.dUp,
                dDwn=geom.dDwn,
            )
        elseif geom isa PointMappedGeometry
            node[:geometry] = PointMappedGeometry(
                geom.ref_mesh,
                geom.point_map;
                params=geom.params,
                transformation=_compose_transformation(transformation, geom.transformation),
            )
        end
    end
end

function apply(t::Transformation, x::RefMesh)
    RefMesh(x.name, apply_transformation_to_mesh(t, x.mesh), x.normals, x.texture_coords, x.material, x.taper)
end
