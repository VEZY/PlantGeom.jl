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

function apply_transformation_to_mesh(transformation::Transformation, mesh)
    transformed_vertices = [apply_transformation_to_point(transformation, p) for p in _vertices(mesh)]
    _mesh(transformed_vertices, _faces(mesh))
end

@inline function _apply_point_map(point_map, p, params)
    applicable(point_map, p, params) && return point_map(p, params)
    return point_map(p)
end

function apply_point_map_to_mesh(point_map, params, mesh)
    transformed_vertices = [point3(_apply_point_map(point_map, p, params)) for p in _vertices(mesh)]
    _mesh(transformed_vertices, _faces(mesh))
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
