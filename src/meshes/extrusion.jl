"""
    extrude_profile_mesh(section, path;
        widths=nothing,
        heights=nothing,
        path_normals=nothing,
        torsion=true,
        close_section=nothing,
        cap_ends=false)

Build a `GeometryBasics.Mesh` by sweeping a profile `section` along a 3D `path`.

This is an AMAP-style extrusion primitive (similar in spirit to AMAPStudio's
`MeshBuilder.ExtrudeData` + `ExtrudedMesh`):
- `section`: profile points in local section coordinates.
- `path`: centerline points.
- `widths` / `heights`: per-path scaling of the section local axes.
- `path_normals`: optional per-path local normal vectors.
- `torsion`: if `false`, uses a fixed-section normal plane (reprojected along path).
- `close_section`: if `true`, connects last/first section points; if `nothing`, auto-detect.
- `cap_ends`: if `true` and section is closed, adds start/end caps.

The returned mesh is expressed in local coordinates, ready to be wrapped in `RefMesh`.
"""
function extrude_profile_mesh(
    section::AbstractVector,
    path::AbstractVector;
    widths=nothing,
    heights=nothing,
    path_normals=nothing,
    torsion::Bool=true,
    close_section=nothing,
    cap_ends::Bool=false,
)
    n_path = length(path)
    n_path >= 2 || error("`path` must contain at least 2 points.")

    section_pts = _coerce_profile_points(section)
    n_section_raw = length(section_pts)
    n_section_raw >= 2 || error("`section` must contain at least 2 points.")

    section_is_closed = _resolve_section_closed(section_pts, close_section)
    if section_is_closed && _points_close(section_pts[1], section_pts[end])
        section_pts = section_pts[1:(end - 1)]
    end

    n_section = length(section_pts)
    n_section >= 2 || error("`section` must contain at least 2 distinct points.")

    path_pts = [_extrusion_vec3(p) for p in path]
    tangents = _compute_path_tangents(path_pts)
    normals = _compute_path_normals(tangents, path_normals, torsion)

    width_vals = _expand_profile_scale(widths, n_path, 1.0)
    height_vals = _expand_profile_scale(heights, n_path, 1.0)

    vertices = _Point3[]
    sizehint!(vertices, n_path * n_section + (cap_ends ? 2 : 0))

    for j in 1:n_path
        u, v, w = _frame_from_tangent_normal(tangents[j], normals[j])
        p = path_pts[j]
        wj = width_vals[j]
        hj = height_vals[j]

        for s in section_pts
            # AMAP-style local section embedding: x on local normal axis, y on
            # secondary axis (with sign convention), z on tangent axis.
            q = p + (s[1] * wj) * u - (s[2] * hj) * v + s[3] * w
            push!(vertices, point3(q))
        end
    end

    faces = Face3[]
    section_segments = section_is_closed ? n_section : (n_section - 1)
    sizehint!(faces, 2 * section_segments * (n_path - 1) + (cap_ends ? 2 * n_section : 0))

    idx(j, i) = (j - 1) * n_section + i

    for j in 1:(n_path - 1)
        for i in 1:section_segments
            i2 = i == n_section ? 1 : i + 1
            a = idx(j, i)
            b = idx(j, i2)
            c = idx(j + 1, i2)
            d = idx(j + 1, i)
            push!(faces, face3(a, b, c))
            push!(faces, face3(a, c, d))
        end
    end

    if cap_ends
        section_is_closed || error("`cap_ends=true` requires a closed section.")
        n_section >= 3 || error("`cap_ends=true` requires at least 3 section points.")

        start_center_acc = SVector{3,Float64}(0.0, 0.0, 0.0)
        end_center_acc = SVector{3,Float64}(0.0, 0.0, 0.0)
        for i in 1:n_section
            start_center_acc += _svec3(vertices[idx(1, i)])
            end_center_acc += _svec3(vertices[idx(n_path, i)])
        end
        start_center = point3(start_center_acc / n_section)
        end_center = point3(end_center_acc / n_section)
        push!(vertices, start_center)
        start_id = length(vertices)
        push!(vertices, end_center)
        end_id = length(vertices)

        for i in 1:n_section
            i2 = i == n_section ? 1 : i + 1
            push!(faces, face3(start_id, idx(1, i2), idx(1, i)))
            push!(faces, face3(end_id, idx(n_path, i), idx(n_path, i2)))
        end
    end

    _mesh(vertices, faces)
end

"""
    circle_section_profile(n_sides=8; radius=0.5, close_loop=true)

Create a circular section profile in local section coordinates (XY plane, `z=0`).

This mirrors AMAPStudio's `Mesh.makeCircle(n, radius)` helper.
When `close_loop=true`, the first point is repeated at the end.
"""
function circle_section_profile(n_sides::Integer=8; radius::Real=0.5, close_loop::Bool=true)
    n = Int(n_sides)
    n >= 3 || error("`n_sides` must be >= 3.")
    r = Float64(radius)

    pts = Vector{_Point3}(undef, n + (close_loop ? 1 : 0))
    for i in 0:(n - 1)
        θ = 2π * (i / n)
        pts[i + 1] = point3(r * cos(θ), r * sin(θ), 0.0)
    end
    if close_loop
        pts[end] = pts[1]
    end
    pts
end

"""
    extrusion_make_path(n, key_points; key_tangents=nothing)

AMAP-style Hermite path interpolation helper (similar to `Mesh.makePath`).

Returns `n + 1` sampled 3D points passing through the key points.
If `key_tangents` is omitted, tangents are estimated from neighboring keys.
"""
function extrusion_make_path(n::Integer, key_points::AbstractVector; key_tangents=nothing)
    n_samples = Int(n)
    n_samples >= 1 || error("`n` must be >= 1.")
    m = length(key_points)
    m >= 2 || error("`key_points` must contain at least 2 points.")

    keys = [_extrusion_vec3(p) for p in key_points]
    tangents = key_tangents === nothing ? _estimate_key_tangents(keys) : _coerce_tangents(key_tangents, m)

    samples = Vector{_Point3}(undef, n_samples + 1)
    nseg = m - 1
    for i in 0:n_samples
        if i == n_samples
            samples[i + 1] = point3(keys[end])
            continue
        end
        f = (i / n_samples) * nseg
        seg = clamp(floor(Int, f) + 1, 1, nseg)
        u = f - (seg - 1)
        p = _hermite_point(keys[seg], keys[seg + 1], tangents[seg], tangents[seg + 1], u)
        samples[i + 1] = point3(p)
    end
    samples
end

"""
    extrusion_make_spline(n, key_points)

AMAP-style spline helper (similar to `Mesh.makeSpline`) using Catmull-Rom interpolation.

Returns `n + 1` sampled 3D points passing near the key points.
"""
function extrusion_make_spline(n::Integer, key_points::AbstractVector)
    n_samples = Int(n)
    n_samples >= 1 || error("`n` must be >= 1.")
    m = length(key_points)
    m >= 2 || error("`key_points` must contain at least 2 points.")

    keys = [_extrusion_vec3(p) for p in key_points]
    if m == 2
        return [point3((1 - t) * keys[1] + t * keys[2]) for t in range(0.0, 1.0; length=n_samples + 1)]
    end

    samples = Vector{_Point3}(undef, n_samples + 1)
    nseg = m - 1
    for i in 0:n_samples
        if i == n_samples
            samples[i + 1] = point3(keys[end])
            continue
        end
        f = (i / n_samples) * nseg
        seg = clamp(floor(Int, f) + 1, 1, nseg)
        u = f - (seg - 1)
        p0 = keys[max(seg - 1, 1)]
        p1 = keys[seg]
        p2 = keys[seg + 1]
        p3 = keys[min(seg + 2, m)]
        p = _catmull_rom_point(p0, p1, p2, p3, u)
        samples[i + 1] = point3(p)
    end
    samples
end

"""
    extrusion_make_interpolation(n, key_values)

AMAP-style scalar interpolation helper (similar to `Mesh.makeInterpolation`).

Returns `n + 1` scalar values sampled linearly between key values.
"""
function extrusion_make_interpolation(n::Integer, key_values::AbstractVector)
    n_samples = Int(n)
    n_samples >= 1 || error("`n` must be >= 1.")
    n_keys = length(key_values)
    n_keys >= 2 || error("`key_values` must contain at least 2 values.")

    keys = Float64[Float64(v) for v in key_values]
    out = Vector{Float64}(undef, n_samples + 1)

    for i in 0:(n_samples - 1)
        f = (i / (n_samples + 1e-3)) * (n_keys - 1)
        k = clamp(floor(Int, f) + 1, 1, n_keys - 1)
        α = f - (k - 1)
        out[i + 1] = (1 - α) * keys[k] + α * keys[k + 1]
    end
    out[end] = keys[end]

    out
end

"""
    extrusion_make_curve(z_keys, r_keys, n)

AMAP-style radial curve helper (similar to `Mesh.makeCurve`), used by `lathe`.

This interpolation preserves local extrema in `r_keys` by forcing zero slope at
intermediate local minima/maxima, then sampling with cubic Hermite interpolation.
Returns `(z_samples, r_samples)` with `n + 1` values each.
"""
function extrusion_make_curve(z_keys::AbstractVector, r_keys::AbstractVector, n::Integer)
    length(z_keys) == length(r_keys) || error("`z_keys` and `r_keys` must have same length.")
    length(z_keys) >= 2 || error("Need at least 2 key points.")

    n_samples = Int(n)
    n_samples >= 1 || error("`n` must be >= 1.")

    x = Float64[Float64(v) for v in z_keys]
    y = Float64[Float64(v) for v in r_keys]
    n_keys = length(x)

    slopes = zeros(Float64, n_keys)
    for i in 2:(n_keys - 1)
        extrema = (y[i] >= y[i - 1]) == (y[i] >= y[i + 1])
        if extrema
            slopes[i] = 0.0
        else
            num = (y[i + 1] - y[i]) * (x[i] - x[i - 1]) + (y[i] - y[i - 1]) * (x[i + 1] - x[i])
            den = (x[i + 1] - x[i - 1])^2
            slopes[i] = den == 0.0 ? 0.0 : num / den
        end
    end
    d_start = x[2] - x[1]
    d_end = x[end] - x[end - 1]
    slopes[1] = d_start == 0.0 ? 0.0 : (2 * (y[2] - y[1]) / d_start - slopes[2])
    slopes[end] = d_end == 0.0 ? 0.0 : (2 * (y[end] - y[end - 1]) / d_end - slopes[end - 1])

    z_samples = Vector{Float64}(undef, n_samples + 1)
    r_samples = Vector{Float64}(undef, n_samples + 1)
    for j in 1:(n_samples + 1)
        t = (j - 1) / (n_samples + 0.01)
        xv = x[1] + t * (x[end] - x[1])
        seg = _curve_segment_for_x(x, xv)
        z_samples[j] = xv
        r_samples[j] = _hermite_scalar(
            x[seg],
            x[seg + 1],
            y[seg],
            y[seg + 1],
            slopes[seg],
            slopes[seg + 1],
            xv,
        )
    end

    z_samples[end] = x[end]
    r_samples[end] = y[end]
    z_samples, r_samples
end

"""
    extrude_tube_mesh(path;
        n_sides=8,
        radius=0.5,
        radii=nothing,
        widths=nothing,
        heights=nothing,
        path_normals=nothing,
        torsion=true,
        cap_ends=false)

Convenience wrapper to extrude a circular section along a path.

- `radius`: base circular section radius.
- `radii`: per-path isotropic scaling (applied to both width and height).
- `widths` / `heights`: optional anisotropic per-path scaling.

`widths`/`heights` take precedence over `radii` when explicitly provided.
"""
function extrude_tube_mesh(
    path::AbstractVector;
    n_sides::Integer=8,
    radius::Real=0.5,
    radii=nothing,
    widths=nothing,
    heights=nothing,
    path_normals=nothing,
    torsion::Bool=true,
    cap_ends::Bool=false,
)
    section = circle_section_profile(n_sides; radius=radius, close_loop=true)

    wvals = widths
    hvals = heights
    if radii !== nothing
        wvals === nothing && (wvals = radii)
        hvals === nothing && (hvals = radii)
    end

    extrude_profile_mesh(
        section,
        path;
        widths=wvals,
        heights=hvals,
        path_normals=path_normals,
        torsion=torsion,
        close_section=true,
        cap_ends=cap_ends,
    )
end

"""
    lathe_gen_mesh(n_sides, z_coords, radii;
        axis=:x, cap_ends=false)

AMAP-style lathe generator (similar to `latheGen`): revolve sampled radii
around the main axis.
"""
function lathe_gen_mesh(
    n_sides::Integer,
    z_coords::AbstractVector,
    radii::AbstractVector;
    axis::Symbol=:x,
    cap_ends::Bool=false,
)
    length(z_coords) == length(radii) || error("`z_coords` and `radii` must have same length.")
    length(z_coords) >= 2 || error("Need at least 2 sampled points.")
    n_sides >= 3 || error("`n_sides` must be >= 3.")

    path = [_axis_point(Float64(z), axis) for z in z_coords]
    rv = Float64[Float64(r) for r in radii]
    any(<(0.0), rv) && error("`radii` values must be >= 0.")

    extrude_tube_mesh(
        path;
        n_sides=Int(n_sides),
        radius=1.0,
        radii=rv,
        torsion=false,
        cap_ends=cap_ends,
    )
end

"""
    lathe_gen_refmesh(name, n_sides, z_coords, radii;
        material=RGB(220 / 255, 220 / 255, 220 / 255),
        cache=nothing,
        axis=:x,
        cap_ends=false)

Create a `RefMesh` from [`lathe_gen_mesh`](@ref).
"""
function lathe_gen_refmesh(
    name::AbstractString,
    n_sides::Integer,
    z_coords::AbstractVector,
    radii::AbstractVector;
    material=RGB(220 / 255, 220 / 255, 220 / 255),
    cache=nothing,
    axis::Symbol=:x,
    cap_ends::Bool=false,
)
    key = (
        :lathe_gen,
        String(name),
        Int(n_sides),
        _hashable_values(z_coords),
        _hashable_values(radii),
        axis,
        cap_ends,
        material,
    )
    builder() = begin
        mesh = lathe_gen_mesh(n_sides, z_coords, radii; axis=axis, cap_ends=cap_ends)
        RefMesh(String(name), mesh, material)
    end
    if cache === nothing
        return builder()
    end
    return get!(cache, key) do
        builder()
    end
end

"""
    lathe_mesh(n_sides, n, z_keys, r_keys;
        method=:curve,
        axis=:x,
        cap_ends=false)

AMAP-style lathe with key profiles (similar to `lathe`):
- `method=:curve` matches AMAP `makeCurve` behavior (local extrema preserving).
- `method=:spline` uses Catmull-Rom interpolation.
- `method=:path` uses Hermite interpolation.
"""
function lathe_mesh(
    n_sides::Integer,
    n::Integer,
    z_keys::AbstractVector,
    r_keys::AbstractVector;
    method::Symbol=:curve,
    axis::Symbol=:x,
    cap_ends::Bool=false,
)
    length(z_keys) == length(r_keys) || error("`z_keys` and `r_keys` must have same length.")
    length(z_keys) >= 2 || error("Need at least 2 key points.")

    z = Float64[]
    r = Float64[]
    if method === :curve
        z, r = extrusion_make_curve(z_keys, r_keys, n)
    else
        keys = [SVector{3,Float64}(Float64(z_keys[i]), Float64(r_keys[i]), 0.0) for i in eachindex(z_keys)]
        sampled = if method === :spline
            extrusion_make_spline(n, keys)
        elseif method === :path
            tangents = _lathe_key_tangents(keys)
            extrusion_make_path(n, keys; key_tangents=tangents)
        else
            error("Unknown `method=$method`. Use `:curve`, `:spline` or `:path`.")
        end
        z = Float64[p[1] for p in sampled]
        r = Float64[p[2] for p in sampled]
    end

    r = Float64[max(v, 0.0) for v in r]
    lathe_gen_mesh(n_sides, z, r; axis=axis, cap_ends=cap_ends)
end

"""
    lathe_refmesh(name, n_sides, n, z_keys, r_keys;
        material=RGB(220 / 255, 220 / 255, 220 / 255),
        cache=nothing,
        method=:curve,
        axis=:x,
        cap_ends=false)

Create a `RefMesh` from [`lathe_mesh`](@ref).
"""
function lathe_refmesh(
    name::AbstractString,
    n_sides::Integer,
    n::Integer,
    z_keys::AbstractVector,
    r_keys::AbstractVector;
    material=RGB(220 / 255, 220 / 255, 220 / 255),
    cache=nothing,
    method::Symbol=:curve,
    axis::Symbol=:x,
    cap_ends::Bool=false,
)
    key = (
        :lathe,
        String(name),
        Int(n_sides),
        Int(n),
        _hashable_values(z_keys),
        _hashable_values(r_keys),
        method,
        axis,
        cap_ends,
        material,
    )
    builder() = begin
        mesh = lathe_mesh(
            n_sides,
            n,
            z_keys,
            r_keys;
            method=method,
            axis=axis,
            cap_ends=cap_ends,
        )
        RefMesh(String(name), mesh, material)
    end
    if cache === nothing
        return builder()
    end
    return get!(cache, key) do
        builder()
    end
end

"""
    extrude_profile_refmesh(name, section, path;
        material=RGB(220 / 255, 220 / 255, 220 / 255),
        cache=nothing,
        widths=nothing,
        heights=nothing,
        path_normals=nothing,
        torsion=true,
        close_section=nothing,
        cap_ends=false)

Create a `RefMesh` directly from [`extrude_profile_mesh`](@ref).

Extrusion options are forwarded to `extrude_profile_mesh`.
"""
function extrude_profile_refmesh(
    name::AbstractString,
    section,
    path;
    material=RGB(220 / 255, 220 / 255, 220 / 255),
    cache=nothing,
    widths=nothing,
    heights=nothing,
    path_normals=nothing,
    torsion::Bool=true,
    close_section=nothing,
    cap_ends::Bool=false,
)
    key = (
        :profile,
        String(name),
        _hashable_points(section),
        _hashable_points(path),
        _hashable_values(widths),
        _hashable_values(heights),
        _hashable_points(path_normals),
        torsion,
        close_section === nothing ? :auto : Bool(close_section),
        cap_ends,
        material,
    )
    builder() = begin
        mesh = extrude_profile_mesh(
            section,
            path;
            widths=widths,
            heights=heights,
            path_normals=path_normals,
            torsion=torsion,
            close_section=close_section,
            cap_ends=cap_ends,
        )
        RefMesh(String(name), mesh, material)
    end
    if cache === nothing
        return builder()
    end
    return get!(cache, key) do
        builder()
    end
end

"""
    leaflet_midrib_profile(; lamina_angle_deg=40.0, scale=0.5)

Return a 3-point open section profile commonly used to mimic a leaflet with a
central midrib (AMAP-style V section).

The profile lies in local section coordinates and is typically swept along the
organ length axis with [`extrude_profile_mesh`](@ref).
"""
function leaflet_midrib_profile(; lamina_angle_deg::Real=40.0, scale::Real=0.5)
    half_angle = deg2rad(Float64(lamina_angle_deg)) / 2
    s = Float64(scale)
    x = s * sin(half_angle)
    y = s * cos(half_angle)
    [
        point3(-x, -y, 0.0),
        point3(0.0, 0.0, 0.0),
        point3(x, -y, 0.0),
    ]
end

@inline function _axis_point(s::Float64, axis::Symbol)
    if axis === :x
        return point3(s, 0.0, 0.0)
    elseif axis === :y
        return point3(0.0, s, 0.0)
    elseif axis === :z
        return point3(0.0, 0.0, s)
    else
        error("`axis` must be one of :x, :y, :z, got $axis.")
    end
end

function _coerce_tangents(ts::AbstractVector, n::Int)
    length(ts) == n || error("`key_tangents` must match `key_points` length ($n).")
    [_extrusion_vec3(t) for t in ts]
end

function _estimate_key_tangents(keys::AbstractVector{SVector{3,Float64}})
    n = length(keys)
    tangents = Vector{SVector{3,Float64}}(undef, n)
    for i in 1:n
        tangents[i] = if i == 1
            keys[2] - keys[1]
        elseif i == n
            keys[n] - keys[n - 1]
        else
            0.5 * (keys[i + 1] - keys[i - 1])
        end
    end
    tangents
end

@inline function _hermite_point(p0, p1, t0, t1, u::Float64)
    u2 = u * u
    u3 = u2 * u
    h00 = 2u3 - 3u2 + 1
    h10 = u3 - 2u2 + u
    h01 = -2u3 + 3u2
    h11 = u3 - u2
    h00 * p0 + h10 * t0 + h01 * p1 + h11 * t1
end

@inline function _catmull_rom_point(p0, p1, p2, p3, u::Float64)
    u2 = u * u
    u3 = u2 * u
    0.5 * (
        (2 * p1) +
        (-p0 + p2) * u +
        (2p0 - 5p1 + 4p2 - p3) * u2 +
        (-p0 + 3p1 - 3p2 + p3) * u3
    )
end

function _lathe_key_tangents(keys::AbstractVector{SVector{3,Float64}})
    _estimate_key_tangents(keys)
end

function _curve_segment_for_x(x::AbstractVector{Float64}, xv::Float64)
    n = length(x)
    for i in 1:(n - 1)
        if (xv >= x[i]) != (xv >= x[i + 1])
            return i
        end
    end
    return n - 1
end

@inline function _hermite_scalar(
    x0::Float64,
    x1::Float64,
    y0::Float64,
    y1::Float64,
    s0::Float64,
    s1::Float64,
    x::Float64,
)
    (x1 - x0) == 0.0 && return y0
    t = (x - x0) / (x1 - x0)
    s = 1 - t
    y0 * s * s * (3 - 2 * s) + s0 * (1 - s) * s * s - s1 * (1 - t) * t * t + y1 * t * t * (3 - 2 * t)
end

function _hashable_points(x)
    x === nothing && return nothing
    return Tuple((Tuple(_extrusion_vec3(p)) for p in x))
end

function _hashable_values(x)
    x === nothing && return nothing
    if x isa Number
        return Float64(x)
    end
    Tuple(Float64(v) for v in x)
end

@inline function _extrusion_vec3(x)
    n = try
        length(x)
    catch
        throw(ArgumentError("Point/vector-like input must support indexing and length. Got $(typeof(x))."))
    end
    n == 2 || n == 3 || throw(ArgumentError("Expected a 2D or 3D point-like input, got length=$n."))
    z = n == 3 ? Float64(x[3]) : 0.0
    SVector{3,Float64}(Float64(x[1]), Float64(x[2]), z)
end

function _coerce_profile_points(section::AbstractVector)
    [_extrusion_vec3(p) for p in section]
end

@inline _points_close(a, b; atol=1e-10) = norm(a - b) <= atol

function _resolve_section_closed(section_pts::AbstractVector, close_section)
    if close_section === nothing
        return length(section_pts) >= 3 && _points_close(section_pts[1], section_pts[end])
    end
    Bool(close_section)
end

function _expand_profile_scale(x, n::Int, default::Float64)
    if x === nothing
        return fill(default, n)
    elseif x isa Number
        return fill(Float64(x), n)
    else
        length(x) == n || error("Scale vector length must match path length ($n), got $(length(x)).")
        return Float64[Float64(v) for v in x]
    end
end

function _compute_path_tangents(path_pts::AbstractVector)
    n = length(path_pts)
    tangents = Vector{SVector{3,Float64}}(undef, n)
    fallback = SVector{3,Float64}(1.0, 0.0, 0.0)

    for i in 1:n
        raw = if i == 1
            path_pts[2] - path_pts[1]
        elseif i == n
            path_pts[n] - path_pts[n - 1]
        else
            path_pts[i + 1] - path_pts[i - 1]
        end
        tangents[i] = _normalize_or_fallback(raw, fallback)
        fallback = tangents[i]
    end

    tangents
end

@inline function _normalize_or_fallback(v::SVector{3,Float64}, fallback::SVector{3,Float64})
    nv = norm(v)
    if nv <= 1e-12
        return fallback
    end
    v / nv
end

@inline function _fallback_perpendicular(t::SVector{3,Float64})
    z = SVector{3,Float64}(0.0, 0.0, 1.0)
    y = SVector{3,Float64}(0.0, 1.0, 0.0)
    abs(dot(t, z)) < 0.95 ? z : y
end

function _project_normal(seed::SVector{3,Float64}, tangent::SVector{3,Float64})
    n = seed - dot(seed, tangent) * tangent
    if norm(n) <= 1e-12
        fallback = _fallback_perpendicular(tangent)
        n = fallback - dot(fallback, tangent) * tangent
    end
    _normalize_or_fallback(n, _fallback_perpendicular(tangent))
end

function _compute_path_normals(tangents::AbstractVector, path_normals, torsion::Bool)
    n = length(tangents)
    normals = Vector{SVector{3,Float64}}(undef, n)

    if path_normals === nothing
        seed = _fallback_perpendicular(tangents[1])
        normals[1] = _project_normal(seed, tangents[1])
        base_seed = normals[1]
        for i in 2:n
            seed_i = torsion ? normals[i - 1] : base_seed
            normals[i] = _project_normal(seed_i, tangents[i])
        end
        return normals
    end

    length(path_normals) == n || error("`path_normals` length must match path length ($n), got $(length(path_normals)).")
    normals_in = [_extrusion_vec3(v) for v in path_normals]
    base_seed = _project_normal(normals_in[1], tangents[1])
    normals[1] = base_seed
    for i in 2:n
        seed_i = torsion ? normals_in[i] : base_seed
        normals[i] = _project_normal(seed_i, tangents[i])
    end
    normals
end

function _frame_from_tangent_normal(
    tangent::SVector{3,Float64},
    normal::SVector{3,Float64},
)
    w = _normalize_or_fallback(tangent, SVector{3,Float64}(1.0, 0.0, 0.0))
    u0 = _project_normal(normal, w)
    v_raw = cross(w, u0)
    v = _normalize_or_fallback(v_raw, _fallback_perpendicular(w))
    u = _normalize_or_fallback(cross(v, w), u0)
    return u, v, w
end
