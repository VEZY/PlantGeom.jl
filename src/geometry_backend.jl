const _Point3 = GeometryBasics.Point{3,Float64}
const _Vec3 = GeometryBasics.Vec{3,Float64}
const Face3 = GeometryBasics.TriangleFace{Int}

@inline function point3(x, y, z)
    _Point3(Float64(x), Float64(y), Float64(z))
end

@inline function point3(v::Union{Tuple,AbstractVector,StaticArrays.StaticVector})
    point3(v[1], v[2], v[3])
end

@inline function vec3(x, y, z)
    _Vec3(Float64(x), Float64(y), Float64(z))
end

@inline function vec3(v::Union{Tuple,AbstractVector,StaticArrays.StaticVector})
    vec3(v[1], v[2], v[3])
end

@inline function _svec3(v::Union{Tuple,AbstractVector,StaticArrays.StaticVector})
    SVector{3,Float64}(Float64(v[1]), Float64(v[2]), Float64(v[3]))
end

@inline _svec3(p::GeometryBasics.AbstractPoint{3}) = SVector{3,Float64}(Float64(p[1]), Float64(p[2]), Float64(p[3]))

@inline function face3(i, j, k)
    Face3(Int(Base.to_index(i)), Int(Base.to_index(j)), Int(Base.to_index(k)))
end

@inline face3(f::GeometryBasics.AbstractFace) = face3(f[1], f[2], f[3])

# Uniform mesh accessors for GeometryBasics meshes.
_vertices(mesh) = collect(GeometryBasics.coordinates(mesh))
_faces(mesh) = collect(GeometryBasics.faces(mesh))
_nvertices(mesh) = length(_vertices(mesh))
_nfaces(mesh) = length(_faces(mesh))

function _mesh(vertices::AbstractVector, faces::AbstractVector)
    GeometryBasics.Mesh(point3.(vertices), face3.(faces))
end

function _merge_meshes(meshes::AbstractVector)
    isempty(meshes) && return _mesh(_Point3[], Face3[])
    normalized = [_mesh(_vertices(m), _faces(m)) for m in meshes]
    merged = GeometryBasics.merge(normalized)
    _mesh(_vertices(merged), _faces(merged))
end

function apply_transformation_to_point(transformation::Transformation, p)
    point3(transformation(_svec3(p)))
end

"""
    OrientedPointMap(map; orientation)

Declare the constant handedness of a callable point map: `orientation=1` for
an orientation-preserving map, or `orientation=-1` for a reflection. Mesh
materialization reverses triangle winding once for the latter, preserving the
authored side of a surface. Both `map(point)` and `map(point, params)` are
supported, using the same dispatch rules as [`PointMappedGeometry`](@ref).

This is a caller-supplied contract, not a numerical orientation detector. Only
use it when the map has the declared orientation throughout the mesh domain;
it does not repair folds, singularities or self-intersections. Unwrapped
arbitrary callables retain their supplied face order.
"""
struct OrientedPointMap{M}
    map::M
    orientation::Int

    function OrientedPointMap(map::M; orientation::Integer) where {M}
        orientation in (-1, 1) || throw(ArgumentError("`orientation` must be -1 or 1."))
        new{M}(map, Int(orientation))
    end
end

@inline (map::OrientedPointMap)(p) = map.map(p)
@inline (map::OrientedPointMap)(p, params) = _apply_point_map(map.map, p, params)

# Only known affine maps provide a global orientation. An arbitrary callable or
# nonlinear Transformation is not classified from its images of the basis, or
# from a derivative at one point: either can conceal a fold or a singularity.
# A declared point-map orientation is the sole non-affine exception.
@inline _affine_orientation_parity(::IdentityTransformation) = 1
@inline _affine_orientation_parity(::Translation) = 1
@inline _affine_orientation_parity(::typeof(identity)) = 1
@inline _affine_orientation_parity(map::OrientedPointMap) = map.orientation

@inline function _linear_orientation_parity(linear)
    if linear isa UniformScaling
        value = linear.λ
        isfinite(value) && !iszero(value) || return 0
        return value < 0 ? -1 : 1
    end
    matrix = SMatrix{3,3,Float64}(linear)
    all(isfinite, matrix) || return 0
    # Each positive column scale leaves the determinant sign unchanged. Scale
    # columns independently so both huge uniform scales and extreme anisotropy
    # avoid overflowing or underflowing the determinant before its sign is read.
    a, b, c = matrix[:, 1], matrix[:, 2], matrix[:, 3]
    sa, sb, sc = maximum(abs, a), maximum(abs, b), maximum(abs, c)
    (iszero(sa) || iszero(sb) || iszero(sc)) && return 0
    determinant = det(hcat(a / sa, b / sb, c / sc))
    isfinite(determinant) && !iszero(determinant) || return 0
    return determinant < 0 ? -1 : 1
end

@inline _affine_orientation_parity(t::Union{LinearMap,AffineMap}) =
    _linear_orientation_parity(t.linear)

@inline function _combine_orientation_parity(outer, inner)
    a = _affine_orientation_parity(outer)
    b = _affine_orientation_parity(inner)
    return a === nothing || b === nothing ? nothing : a * b
end

@inline _affine_orientation_parity(t::ComposedTransformation) =
    _combine_orientation_parity(t.t1, t.t2)

function _affine_orientation_parity(map)
    # These types are defined after the backend is included. Keep the checks in
    # the method body so their own arithmetic and application order stay intact.
    if isdefined(@__MODULE__, :SequentialTransformation) && map isa SequentialTransformation
        return _combine_orientation_parity(map.outer, map.inner)
    elseif isdefined(@__MODULE__, :_AxisScalePointMap) && map isa _AxisScalePointMap
        return _linear_orientation_parity(Diagonal(SVector(map.sx, map.sy, map.sz)))
    elseif isdefined(@__MODULE__, :ComposedPointMap) && map isa ComposedPointMap
        parity = 1
        for part in map.maps
            current = _affine_orientation_parity(part)
            current === nothing && return nothing
            parity *= current
        end
        return parity
    end
    return nothing
end

# Return a true constant affine derivative, never a linearization or a matrix
# fitted to basis images. In particular, a declared orientation is not a claim
# that its underlying point map is affine.
@inline _affine_linear_part(::Union{IdentityTransformation,Translation}) =
    SMatrix{3,3,Float64}(I)
@inline _affine_linear_part(::typeof(identity)) = SMatrix{3,3,Float64}(I)
@inline _affine_linear_part(t::Union{LinearMap,AffineMap}) = t.linear

function _composed_affine_linear_part(outer, inner)
    a = _affine_linear_part(outer)
    b = _affine_linear_part(inner)
    return a === nothing || b === nothing ? nothing : a * b
end

@inline _affine_linear_part(t::ComposedTransformation) =
    _composed_affine_linear_part(t.t1, t.t2)

function _affine_linear_part(map)
    if isdefined(@__MODULE__, :SequentialTransformation) && map isa SequentialTransformation
        return _composed_affine_linear_part(map.outer, map.inner)
    elseif isdefined(@__MODULE__, :_AxisScalePointMap) && map isa _AxisScalePointMap
        return Diagonal(SVector(map.sx, map.sy, map.sz))
    elseif isdefined(@__MODULE__, :ComposedPointMap) && map isa ComposedPointMap
        linear = SMatrix{3,3,Float64}(I)
        for part in map.maps
            current = _affine_linear_part(part)
            current === nothing && return nothing
            linear = current * linear
        end
        return linear
    end
    return nothing
end

function _faces_after_map(map, mesh)
    faces = _faces(mesh)
    _affine_orientation_parity(map) === -1 || return faces
    # Preserve the authored side under reflection, rather than attempting to
    # infer an exterior for an imported mesh or an open leaf surface.
    return [face3(f[1], f[3], f[2]) for f in faces]
end

function apply_transformation_to_mesh(transformation::Transformation, mesh)
    transformed_vertices = [apply_transformation_to_point(transformation, p) for p in _vertices(mesh)]
    _mesh(transformed_vertices, _faces_after_map(transformation, mesh))
end

@inline function _apply_point_map(point_map, p, params)
    applicable(point_map, p, params) && return point_map(p, params)
    return point_map(p)
end

function apply_point_map_to_mesh(point_map, params, mesh)
    transformed_vertices = [point3(_apply_point_map(point_map, p, params)) for p in _vertices(mesh)]
    _mesh(transformed_vertices, _faces_after_map(point_map, mesh))
end

function transformation_matrix4(transformation::Transformation)
    origin = SVector{3,Float64}(0.0, 0.0, 0.0)
    p0 = _svec3(transformation(origin))

    linear = try
        Matrix{Float64}(CoordinateTransformations.transform_deriv(transformation, origin))
    catch
        nothing
    end

    if linear === nothing || size(linear) != (3, 3) || any(x -> !isfinite(x), linear)
        px = _svec3(transformation(SVector{3,Float64}(1.0, 0.0, 0.0)))
        py = _svec3(transformation(SVector{3,Float64}(0.0, 1.0, 0.0)))
        pz = _svec3(transformation(SVector{3,Float64}(0.0, 0.0, 1.0)))
        linear = hcat(px - p0, py - p0, pz - p0)
    end

    mat = Matrix{Float64}(I, 4, 4)
    mat[1:3, 1:3] = linear
    mat[1:3, 4] = p0
    mat
end

function face_normal(p1, p2, p3)
    u = _svec3(p2) - _svec3(p1)
    v = _svec3(p3) - _svec3(p1)
    n = cross(u, v)
    nn = norm(n)
    nn == 0.0 ? _Vec3(0.0, 0.0, 0.0) : vec3(n / nn)
end
