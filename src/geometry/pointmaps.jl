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

function RationalBezierCurve(control_points::AbstractVector, weights::AbstractVector=ones(length(control_points)))
    length(control_points) >= 2 || error("`control_points` must contain at least 2 points.")
    length(control_points) == length(weights) || error("`weights` must have the same length as `control_points`.")
    cps = SVector{3,Float64}[_to_svec3(p) for p in control_points]
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
    cereal_leaf_midrib(; length=1.0, base_angle_deg=35.0, bend=0.35, tip_drop=0.12,
        side_sway=0.0, weights=(1.0, 0.8, 0.9, 1.0))

Build a cereal-like leaf midrib as a weighted cubic Bezier curve.

- `base_angle_deg`: launch angle of the leaf at the sheath.
- `bend`: curvature intensity (higher bends more).
- `tip_drop`: additional downward displacement at the tip.
- `side_sway`: lateral displacement of the distal blade.
"""
function cereal_leaf_midrib(;
    length::Real=1.0,
    base_angle_deg::Real=35.0,
    bend::Real=0.35,
    tip_drop::Real=0.12,
    side_sway::Real=0.0,
    weights=(1.0, 0.8, 0.9, 1.0),
)
    len = Float64(length)
    bend01 = clamp(Float64(bend), 0.0, 1.0)
    base_rad = deg2rad(Float64(base_angle_deg))
    tip_drop_abs = len * Float64(tip_drop)
    sway_abs = len * Float64(side_sway)

    p0 = SVector{3,Float64}(0.0, 0.0, 0.0)
    p1 = len * SVector(cos(base_rad) * 0.28, 0.0, sin(base_rad) * 0.28)
    p2 = SVector{3,Float64}(len * (0.52 + 0.10 * bend01), sway_abs * 0.45, len * (0.16 + 0.32 * bend01))
    p3 = SVector{3,Float64}(len, sway_abs, len * (0.05 + 0.10 * sin(base_rad)) - tip_drop_abs)

    RationalBezierCurve([p0, p1, p2, p3], collect(weights))
end

"""
    CerealLeafMap(curve; length=1.0, up=(0, 0, 1))
    CerealLeafMap(; length=1.0, base_angle_deg=35.0, bend=0.35, tip_drop=0.12,
        side_sway=0.0, weights=(1.0, 0.8, 0.9, 1.0), up=(0, 0, 1))

Point-map for cereal leaves. The base reference mesh is expected to use the AMAP
convention: leaf length along local `+X`, width along `+Y`, thickness along `+Z`.

The map bends the leaf by wrapping each local point around a midrib curve while
preserving lateral width and thickness offsets in the local moving frame.
"""
struct CerealLeafMap{C,U}
    curve::C
    length::Float64
    up::U
end

function CerealLeafMap(curve; length::Real=1.0, up=(0.0, 0.0, 1.0))
    CerealLeafMap(curve, Float64(length), _to_svec3(up))
end

function CerealLeafMap(;
    length::Real=1.0,
    base_angle_deg::Real=35.0,
    bend::Real=0.35,
    tip_drop::Real=0.12,
    side_sway::Real=0.0,
    weights=(1.0, 0.8, 0.9, 1.0),
    up=(0.0, 0.0, 1.0),
)
    curve = cereal_leaf_midrib(
        ;
        length=length,
        base_angle_deg=base_angle_deg,
        bend=bend,
        tip_drop=tip_drop,
        side_sway=side_sway,
        weights=weights,
    )
    CerealLeafMap(curve; length=length, up=up)
end

@inline _pointmap_safe_normalize(v::SVector{3,Float64}, fallback::SVector{3,Float64}) = norm(v) > 1e-12 ? v / norm(v) : fallback

function _curve_tangent(curve, u::Float64)
    du = 1e-4
    u0 = clamp(u - du, 0.0, 1.0)
    u1 = clamp(u + du, 0.0, 1.0)
    p0 = _to_svec3(curve(u0))
    p1 = _to_svec3(curve(u1))
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

function (map::CerealLeafMap)(p)
    p_local = _to_svec3(p)
    u = map.length == 0.0 ? 0.0 : clamp(p_local[1] / map.length, 0.0, 1.0)
    center = _to_svec3(map.curve(u))
    _, side, normal = _curve_frame(map.curve, u, map.up)
    center + p_local[2] * side + p_local[3] * normal
end

@inline _cereal_half_width(u::Float64, max_width::Float64, width_power::Float64) =
    0.5 * max_width * sinpi(u)^width_power

"""
    cereal_leaf_mesh(length=1.0, max_width=0.08; n_long=24, n_half=4, width_power=0.85)

Build a flat cereal-like leaf mesh aligned with the AMAP convention:
length along local `+X`, width along `+Y`, thickness along `+Z`.

This mesh is intended to be used with [`PointMappedGeometry`](@ref), especially
with [`CerealLeafMap`](@ref).
"""
function cereal_leaf_mesh(
    length::Real=1.0,
    max_width::Real=0.08;
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
        halfw = _cereal_half_width(u, width, power)
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
    cereal_leaf_refmesh(name; length=1.0, max_width=0.08, n_long=24, n_half=4,
        width_power=0.85, material=RGB(0.16, 0.55, 0.22))

Convenience wrapper around [`cereal_leaf_mesh`](@ref) returning a reusable
`RefMesh`.
"""
function cereal_leaf_refmesh(
    name;
    length::Real=1.0,
    max_width::Real=0.08,
    n_long::Integer=24,
    n_half::Integer=4,
    width_power::Real=0.85,
    material::Union{Material,Colorant}=RGB(0.16, 0.55, 0.22),
)
    RefMesh(
        String(name),
        cereal_leaf_mesh(length, max_width; n_long=n_long, n_half=n_half, width_power=width_power),
        material,
    )
end
