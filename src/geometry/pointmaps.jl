"""
    RationalBezierCurve(control_points, weights=ones(length(control_points)))

Rational Bezier curve in 3D, convenient for point-mapped organs such as cereal
leaves whose midrib is easier to describe from a few weighted control points.

`control_points` are interpreted as 3D positions. `weights` default to 1 for a
standard Bezier curve.
"""
struct RationalBezierCurve{P<:AbstractVector{SVector{3,Float64}},W<:AbstractVector{Float64}}
    control_points::P
    weights::W
end

@inline _pointmap_to_svec3(v) = SVector{3,Float64}(Float64(v[1]), Float64(v[2]), Float64(v[3]))

function RationalBezierCurve(control_points::AbstractVector, weights::AbstractVector=ones(length(control_points)))
    length(control_points) >= 2 || error("`control_points` must contain at least 2 points.")
    length(control_points) == length(weights) || error("`weights` must have the same length as `control_points`.")
    cps = SVector{3,Float64}[_pointmap_to_svec3(p) for p in control_points]
    ws = Float64.(collect(weights))
    RationalBezierCurve(cps, ws)
end

@inline function (curve::RationalBezierCurve)(t::Real)
    u = clamp(Float64(t), 0.0, 1.0)
    n = length(curve.control_points) - 1
    num = SVector{3,Float64}(0.0, 0.0, 0.0)
    den = 0.0
    @inbounds for i in 0:n
        basis = binomial(n, i) * (1.0 - u)^(n - i) * u^i
        w = curve.weights[i + 1] * basis
        num += w * curve.control_points[i + 1]
        den += w
    end
    den == 0.0 && return curve.control_points[1]
    num / den
end

"""
    lamina_midrib(; base_angle_deg=35.0, bend=0.35, tip_drop=0.12,
        side_sway=0.0, weights=(1.0, 0.8, 0.9, 1.0))

Build a cereal-like leaf midrib as a weighted cubic Bezier curve.

- The curve is normalized in a unit frame: length in `[0, 1]`, half-width near `0.5`.
- `base_angle_deg`: launch angle of the leaf at the sheath.
- `bend`: curvature intensity (higher bends more).
- `tip_drop`: additional downward displacement at the tip (relative to unit length).
- `side_sway`: lateral displacement of the distal blade (relative to unit length).
"""
function lamina_midrib(;
    base_angle_deg::Real=35.0,
    bend::Real=0.35,
    tip_drop::Real=0.12,
    side_sway::Real=0.0,
    weights=(1.0, 0.8, 0.9, 1.0),
)
    len = 1.0
    bend01 = clamp(Float64(bend), 0.0, 1.0)
    base_rad = deg2rad(Float64(base_angle_deg))
    tip_drop_abs = len * Float64(tip_drop)
    sway_abs = len * Float64(side_sway)

    p0 = SVector{3,Float64}(0.0, 0.0, 0.0)
    base_dir = SVector{3,Float64}(cos(base_rad), 0.0, sin(base_rad))

    # Increase bend authority by progressively turning the distal tangent downward.
    end_angle_deg = (6.0 + 0.18 * Float64(base_angle_deg)) - 102.0 * bend01
    end_rad = deg2rad(end_angle_deg)
    end_dir = SVector{3,Float64}(cos(end_rad), 0.0, sin(end_rad))

    start_tangent_len = len * (0.34 - 0.10 * bend01)
    end_tangent_len = len * (0.22 + 0.34 * bend01)
    gravity_drop_abs = len * (0.02 + 0.24 * bend01^1.35)
    tip_z = len * (0.04 + 0.08 * sin(base_rad)) - tip_drop_abs - gravity_drop_abs

    p3 = SVector{3,Float64}(len, sway_abs, tip_z)
    p1 = p0 + start_tangent_len * base_dir
    p2_seed = p3 - end_tangent_len * end_dir
    p2 = SVector{3,Float64}(p2_seed[1], sway_abs * 0.45, p2_seed[3] + len * (0.10 * bend01))

    RationalBezierCurve([p0, p1, p2, p3], collect(weights))
end

"""
    LaminaMidribMap(curve; up=(0, 0, 1))
    LaminaMidribMap(; base_angle_deg=35.0, bend=0.35, tip_drop=0.12,
        side_sway=0.0, weights=(1.0, 0.8, 0.9, 1.0), up=(0, 0, 1))

Point-map for lamina deformation around a midrib centerline. The base reference
mesh is expected to use the AMAP convention: leaf length along local `+X`,
width along `+Y`, thickness along `+Z`.
Coordinates are interpreted in a normalized unit frame (`x ∈ [0, 1]`, `|y| ≤ 0.5`).

The map bends the blade by wrapping each local point around a midrib curve while
preserving lateral width and thickness offsets in the local moving frame.
"""
struct LaminaMidribMap{C,U}
    curve::C
    up::U
end

function LaminaMidribMap(curve; up=(0.0, 0.0, 1.0))
    LaminaMidribMap(curve, _pointmap_to_svec3(up))
end

function LaminaMidribMap(;
    base_angle_deg::Real=35.0,
    bend::Real=0.35,
    tip_drop::Real=0.12,
    side_sway::Real=0.0,
    weights=(1.0, 0.8, 0.9, 1.0),
    up=(0.0, 0.0, 1.0),
)
    curve = lamina_midrib(
        ;
        base_angle_deg=base_angle_deg,
        bend=bend,
        tip_drop=tip_drop,
        side_sway=side_sway,
        weights=weights,
    )
    LaminaMidribMap(curve; up=up)
end

@inline _pointmap_safe_normalize(v::SVector{3,Float64}, fallback::SVector{3,Float64}) = norm(v) > 1e-12 ? v / norm(v) : fallback

function _curve_tangent(curve, u::Float64)
    du = 1e-4
    u0 = clamp(u - du, 0.0, 1.0)
    u1 = clamp(u + du, 0.0, 1.0)
    p0 = _pointmap_to_svec3(curve(u0))
    p1 = _pointmap_to_svec3(curve(u1))
    fallback = SVector{3,Float64}(1.0, 0.0, 0.0)
    _pointmap_safe_normalize(p1 - p0, fallback)
end

function _curve_frame(curve, u::Float64, up::SVector{3,Float64})
    tangent = _curve_tangent(curve, u)
    side = cross(up, tangent)
    if norm(side) <= 1e-8
        alt_up = abs(tangent[1]) < 0.9 ? SVector{3,Float64}(1.0, 0.0, 0.0) : SVector{3,Float64}(0.0, 1.0, 0.0)
        side = cross(alt_up, tangent)
    end
    side = _pointmap_safe_normalize(side, SVector{3,Float64}(0.0, 1.0, 0.0))
    normal = _pointmap_safe_normalize(cross(tangent, side), up)
    tangent, side, normal
end

function (map::LaminaMidribMap)(p)
    p_local = _pointmap_to_svec3(p)
    u = clamp(p_local[1], 0.0, 1.0)
    center = _pointmap_to_svec3(map.curve(u))
    _, side, normal = _curve_frame(map.curve, u, map.up)
    center + p_local[2] * side + p_local[3] * normal
end

"""
    LaminaTwistRollMap(; tip_twist_deg=0.0, roll_strength=0.0, roll_exponent=1.0)

Point map for lamina torsion and cross-blade rolling on a flat leaf mesh
following the AMAP axis convention (`+X` length, `+Y` width, `+Z` thickness).

- `tip_twist_deg`: progressive twist (rotation around local `+X`) from base to tip.
- `roll_strength`: quadratic edge curl contribution toward local `+Z`.
- `roll_exponent`: progression exponent along the blade (`u^roll_exponent`).
"""
struct LaminaTwistRollMap
    tip_twist_rad::Float64
    roll_strength::Float64
    roll_exponent::Float64
end

function LaminaTwistRollMap(;
    tip_twist_deg::Real=0.0,
    roll_strength::Real=0.0,
    roll_exponent::Real=1.0,
)
    LaminaTwistRollMap(
        deg2rad(Float64(tip_twist_deg)),
        Float64(roll_strength),
        max(Float64(roll_exponent), 0.0),
    )
end

function (map::LaminaTwistRollMap)(p)
    q = _pointmap_to_svec3(p)
    u = clamp(q[1], 0.0, 1.0)
    twist = map.tip_twist_rad * u
    c = cos(twist)
    s = sin(twist)
    y_tw = c * q[2] - s * q[3]
    z_tw = s * q[2] + c * q[3]
    roll_prog = u^map.roll_exponent
    z_roll = z_tw + map.roll_strength * roll_prog * y_tw^2
    SVector{3,Float64}(q[1], y_tw, z_roll)
end

"""
    LaminaAnticlasticWaveMap(; amplitude=0.06,
        wavelength=0.20, edge_exponent=1.5, progression_exponent=1.0,
        base_damping=4.0, phase_deg=0.0, asymmetry=0.0, lateral_strength=0.0,
        vertical_strength=1.0)

Point map for cereal-like anticlastic undulation. It applies opposite-signed
deformation on the two sides of the lamina (for a given `x`, one margin goes
up while the other goes down), with sinusoidal variation along blade length
(`+X`) and amplitude growth toward margins (`|Y|`), while keeping the midrib
stable (`Y = 0`).
Coordinates are interpreted in a normalized unit frame (`x ∈ [0, 1]`, `|y| ≤ 0.5`).

- `amplitude`: peak local `+Z` displacement magnitude at margins.
- `wavelength`: sinusoid wavelength along local `+X`.
- `edge_exponent`: controls how sharply ripple grows from midrib to margins.
- `progression_exponent`: controls wave growth from base to tip (`u^p`).
- `base_damping`: additional base damping (`1 - exp(-base_damping*u)`).
- `asymmetry`: side gain imbalance in `[-1, 1]` (`+Y` vs `-Y`).
- `lateral_strength`: share of ripple applied to local `+/-Y` (edge outline).
- `vertical_strength`: share of ripple applied to local `+/-Z` (opposite by side).
"""
struct LaminaAnticlasticWaveMap
    amplitude::Float64
    wavelength::Float64
    edge_exponent::Float64
    progression_exponent::Float64
    base_damping::Float64
    phase_rad::Float64
    asymmetry::Float64
    lateral_strength::Float64
    vertical_strength::Float64
end

function LaminaAnticlasticWaveMap(;
    amplitude::Real=0.06,
    wavelength::Real=0.20,
    edge_exponent::Real=1.5,
    progression_exponent::Real=1.0,
    base_damping::Real=4.0,
    phase_deg::Real=0.0,
    asymmetry::Real=0.0,
    lateral_strength::Real=0.0,
    vertical_strength::Real=1.0,
)
    LaminaAnticlasticWaveMap(
        Float64(amplitude),
        max(Float64(wavelength), 0.0),
        max(Float64(edge_exponent), 0.0),
        max(Float64(progression_exponent), 0.0),
        max(Float64(base_damping), 0.0),
        deg2rad(Float64(phase_deg)),
        clamp(Float64(asymmetry), -1.0, 1.0),
        Float64(lateral_strength),
        Float64(vertical_strength),
    )
end

function (map::LaminaAnticlasticWaveMap)(p)
    q = _pointmap_to_svec3(p)
    if map.wavelength <= 1e-12 || map.amplitude == 0.0
        return q
    end

    u = clamp(q[1], 0.0, 1.0)
    edge01 = clamp(abs(q[2]) / 0.5, 0.0, 1.0)
    edge_gain = edge01^map.edge_exponent
    base_gate = map.base_damping == 0.0 ? 1.0 : 1.0 - exp(-map.base_damping * u)
    along_gain = (u^map.progression_exponent) * base_gate
    side_sign = sign(q[2])
    side_gain = q[2] == 0.0 ? 1.0 : max(0.0, 1.0 + map.asymmetry * side_sign)
    phase = 2π * q[1] / map.wavelength + map.phase_rad
    ripple_mag = map.amplitude * edge_gain * along_gain * side_gain * sin(phase)
    ripple_signed = ripple_mag * side_sign
    dy = map.lateral_strength * ripple_signed
    dz = map.vertical_strength * ripple_signed
    SVector{3,Float64}(q[1], q[2] + dy, q[3] + dz)
end

"""
    PointMapFrame(map; length=1.0, width=1.0, z_scale=length)
    with_point_map_frame(map; length=1.0, width=1.0, z_scale=length)

Apply dimensions before midrib wrapping when using normalized lamina maps.

This wrapper is intended for:
- `LaminaMidribMap`
- `ComposedPointMap(..., LaminaMidribMap(...))`

Input coordinates are expected in normalized blade space when calling the map
directly. When used through `PointMappedGeometry`, source coordinates are
auto-normalized from the reference mesh bounds before this frame map is
applied. `length` scales the midrib centerline, while `width` and `z_scale`
scale lateral and thickness offsets in the local side/normal frame of the
midrib (instead of anisotropic world-axis scaling after deformation).
"""
struct PointMapFrame{M}
    map::M
    length::Float64
    width::Float64
    z_scale::Float64
end

function PointMapFrame(map; length::Real=1.0, width::Real=1.0, z_scale::Real=length)
    len = Float64(length)
    wid = Float64(width)
    zsc = Float64(z_scale)
    len > 0.0 || error("`length` must be > 0.")
    wid > 0.0 || error("`width` must be > 0.")
    zsc > 0.0 || error("`z_scale` must be > 0.")
    PointMapFrame(map, len, wid, zsc)
end

with_point_map_frame(map; length::Real=1.0, width::Real=1.0, z_scale::Real=length) =
    PointMapFrame(map; length=length, width=width, z_scale=z_scale)

struct _PointMapInputFrame
    x_min::Float64
    inv_x_span::Float64
    y_mid::Float64
    inv_y_span::Float64
    z_mid::Float64
    inv_z_span::Float64
end

@inline _safe_inv_span(span::Float64) = span > 1e-12 ? 1.0 / span : 1.0

function _point_map_input_frame(mesh)
    verts = _vertices(mesh)
    isempty(verts) && return _PointMapInputFrame(0.0, 1.0, 0.0, 1.0, 0.0, 1.0)

    xmin = Inf
    xmax = -Inf
    ymin = Inf
    ymax = -Inf
    zmin = Inf
    zmax = -Inf

    @inbounds for p in verts
        x = Float64(p[1])
        y = Float64(p[2])
        z = Float64(p[3])
        x < xmin && (xmin = x)
        x > xmax && (xmax = x)
        y < ymin && (ymin = y)
        y > ymax && (ymax = y)
        z < zmin && (zmin = z)
        z > zmax && (zmax = z)
    end

    x_span = xmax - xmin
    y_span = ymax - ymin
    z_span = zmax - zmin
    z_norm_span = x_span > 1e-12 ? x_span : max(y_span, z_span, 1.0)

    _PointMapInputFrame(
        xmin,
        _safe_inv_span(x_span),
        0.5 * (ymin + ymax),
        _safe_inv_span(y_span),
        0.5 * (zmin + zmax),
        _safe_inv_span(z_norm_span),
    )
end

@inline function _normalize_point_map_input(frame::_PointMapInputFrame, p)
    q = _pointmap_to_svec3(p)
    SVector{3,Float64}(
        (q[1] - frame.x_min) * frame.inv_x_span,
        (q[2] - frame.y_mid) * frame.inv_y_span,
        (q[3] - frame.z_mid) * frame.inv_z_span,
    )
end

struct _FramedPointMap{M}
    map::M
    input_frame::_PointMapInputFrame
end

@inline (map::_FramedPointMap)(p) = map.map(_normalize_point_map_input(map.input_frame, p))

function _prepare_point_map_for_ref_mesh(ref_mesh::RefMesh, point_map::PointMapFrame)
    _FramedPointMap(point_map, _point_map_input_frame(ref_mesh.mesh))
end

function PointMappedGeometry(
    ref_mesh::M,
    point_map::PointMapFrame;
    params=nothing,
    transformation=IdentityTransformation(),
) where {M<:RefMesh}
    normalized_map = _prepare_point_map_for_ref_mesh(ref_mesh, point_map)
    PointMappedGeometry(ref_mesh, normalized_map; params=params, transformation=transformation)
end

@inline function _apply_lamina_midrib_framed(map::LaminaMidribMap, q::SVector{3,Float64}, length::Float64, width::Float64, z_scale::Float64)
    u = clamp(q[1], 0.0, 1.0)
    center = _pointmap_to_svec3(map.curve(u))
    _, side, normal = _curve_frame(map.curve, u, map.up)
    (length * center) + (q[2] * width) * side + (q[3] * z_scale) * normal
end

@inline function _apply_tuple_maps(maps::Tuple, q::SVector{3,Float64})
    r = q
    @inbounds for m in maps
        r = _pointmap_to_svec3(m(r))
    end
    r
end

function (frame::PointMapFrame{<:LaminaMidribMap})(p)
    q = _pointmap_to_svec3(p)
    _apply_lamina_midrib_framed(frame.map, q, frame.length, frame.width, frame.z_scale)
end

function (frame::PointMapFrame)(p)
    map = frame.map
    if isdefined(@__MODULE__, :ComposedPointMap) && map isa ComposedPointMap
        maps = map.maps
        last_map = maps[end]
        last_map isa LaminaMidribMap || error("`PointMapFrame` expects a `LaminaMidribMap` or a composition ending with one.")
        q = _pointmap_to_svec3(p)
        q_prefix = _apply_tuple_maps(Base.front(maps), q)
        return _apply_lamina_midrib_framed(last_map, q_prefix, frame.length, frame.width, frame.z_scale)
    end
    error("`PointMapFrame` currently supports `LaminaMidribMap` and compositions ending with it.")
end

"""
    ComposedPointMap(maps...)
    compose_point_maps(maps...)

Compose multiple point maps into a single callable map, applied from left to
right (`maps[1]` then `maps[2]`, ...).
"""
struct ComposedPointMap{M<:Tuple}
    maps::M
end

function ComposedPointMap(maps...)
    length(maps) >= 1 || error("Provide at least one point map.")
    ComposedPointMap(tuple(maps...))
end

compose_point_maps(maps...) = ComposedPointMap(maps...)

function (map::ComposedPointMap)(p)
    q = _pointmap_to_svec3(p)
    @inbounds for m in map.maps
        q = _pointmap_to_svec3(m(q))
    end
    q
end

@inline _lamina_half_width(u::Float64, max_width::Float64, width_power::Float64) =
    0.5 * max_width * sinpi(u)^width_power

"""
    lamina_mesh(length=1.0, max_width=1.0; n_long=24, n_half=4, width_power=0.85)

Build a flat cereal-like leaf mesh aligned with the AMAP convention:
length along local `+X`, width along `+Y`, thickness along `+Z`.

This mesh is intended to be used with [`PointMappedGeometry`](@ref), especially
with [`LaminaMidribMap`](@ref).
"""
function lamina_mesh(
    length::Real=1.0,
    max_width::Real=1.0;
    n_long::Integer=24,
    n_half::Integer=4,
    width_power::Real=0.85,
)
    n_long_i = Int(n_long)
    n_half_i = Int(n_half)
    n_long_i >= 1 || error("`n_long` must be >= 1.")
    n_half_i >= 1 || error("`n_half` must be >= 1.")

    len = Float64(length)
    width = Float64(max_width)
    power = Float64(width_power)
    cols = 2 * n_half_i + 1

    vertices = _Point3[]
    sizehint!(vertices, (n_long_i + 1) * cols)
    for i in 0:n_long_i
        u = i / n_long_i
        x = len * u
        halfw = _lamina_half_width(u, width, power)
        for j in (-n_half_i):n_half_i
            y = n_half_i == 0 ? 0.0 : halfw * (j / n_half_i)
            push!(vertices, point3(x, y, 0.0))
        end
    end

    idx(i, j) = i * cols + j + n_half_i + 1
    faces = Face3[]
    sizehint!(faces, 2 * n_long_i * (cols - 1))
    for i in 0:(n_long_i - 1)
        for j in (-n_half_i):(n_half_i - 1)
            a = idx(i, j)
            b = idx(i, j + 1)
            c = idx(i + 1, j + 1)
            d = idx(i + 1, j)
            push!(faces, face3(a, b, c))
            push!(faces, face3(a, c, d))
        end
    end

    _mesh(vertices, faces)
end

"""
    lamina_refmesh(name; length=1.0, max_width=1.0, n_long=24, n_half=4,
        width_power=0.85, material=RGB(0.16, 0.55, 0.22))

Convenience wrapper around [`lamina_mesh`](@ref) returning a reusable
`RefMesh`.
"""
function lamina_refmesh(
    name;
    length::Real=1.0,
    max_width::Real=1.0,
    n_long::Integer=24,
    n_half::Integer=4,
    width_power::Real=0.85,
    material::Union{Material,Colorant}=RGB(0.16, 0.55, 0.22),
)
    RefMesh(
        String(name),
        lamina_mesh(length, max_width; n_long=n_long, n_half=n_half, width_power=width_power),
        material,
    )
end
