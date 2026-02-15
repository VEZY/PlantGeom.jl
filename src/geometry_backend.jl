const Point3 = GeometryBasics.Point{3,Float64}
const Vec3 = GeometryBasics.Vec{3,Float64}
const Face3 = GeometryBasics.TriangleFace{Int}

# Left-to-right transform composition helper.
compose_lr(t1::Transformation, t2::Transformation) = t2 ∘ t1

@inline identity_transformation() = IdentityTransformation()

@inline function point3(x, y, z)
    Point3(Float64(x), Float64(y), Float64(z))
end

@inline function point3(v::Union{Tuple,AbstractVector,StaticArrays.StaticVector})
    point3(v[1], v[2], v[3])
end

@inline function vec3(x, y, z)
    Vec3(Float64(x), Float64(y), Float64(z))
end

@inline function vec3(v::Union{Tuple,AbstractVector,StaticArrays.StaticVector})
    vec3(v[1], v[2], v[3])
end

@inline function to_svec3(v::Union{Tuple,AbstractVector,StaticArrays.StaticVector})
    SVector{3,Float64}(Float64(v[1]), Float64(v[2]), Float64(v[3]))
end

@inline to_svec3(p::GeometryBasics.AbstractPoint{3}) = SVector{3,Float64}(Float64(p[1]), Float64(p[2]), Float64(p[3]))

@inline to_point3(v) = point3(v[1], v[2], v[3])

@inline function face3(i, j, k)
    Face3(Int(i), Int(j), Int(k))
end

@inline face3(f::GeometryBasics.AbstractFace) = face3(f[1], f[2], f[3])

# Uniform mesh accessors for GeometryBasics meshes.
_vertices(mesh) = GeometryBasics.decompose(Point3, mesh)
_faces(mesh) = GeometryBasics.decompose(Face3, mesh)
_nvertices(mesh) = length(_vertices(mesh))
_nfaces(mesh) = length(_faces(mesh))

function _mesh(vertices::AbstractVector, faces::AbstractVector)
    GeometryBasics.Mesh(point3.(vertices), face3.(faces))
end

function _merge_meshes(meshes::AbstractVector)
    isempty(meshes) && return GeometryBasics.Mesh(Point3[], Face3[])

    points = Point3[]
    connec = Face3[]
    off = 0

    for m in meshes
        verts = _vertices(m)
        append!(points, verts)

        for f in _faces(m)
            push!(connec, face3(f[1] + off, f[2] + off, f[3] + off))
        end

        off += length(verts)
    end

    GeometryBasics.Mesh(points, connec)
end

function apply_transformation_to_point(transformation::Transformation, p)
    to_point3(transformation(to_svec3(p)))
end

function apply_transformation_to_mesh(transformation::Transformation, mesh)
    _mesh([apply_transformation_to_point(transformation, p) for p in _vertices(mesh)], _faces(mesh))
end

# Build a 4x4 matrix from an affine transformation by probing basis vectors.
function transformation_matrix4(transformation::Transformation)
    p0 = transformation(SVector{3,Float64}(0.0, 0.0, 0.0))
    px = transformation(SVector{3,Float64}(1.0, 0.0, 0.0))
    py = transformation(SVector{3,Float64}(0.0, 1.0, 0.0))
    pz = transformation(SVector{3,Float64}(0.0, 0.0, 1.0))

    c1 = px - p0
    c2 = py - p0
    c3 = pz - p0

    M = Matrix{Float64}(undef, 4, 4)
    M[1:3, 1] = c1
    M[1:3, 2] = c2
    M[1:3, 3] = c3
    M[1:3, 4] = p0
    M[4, 1:3] .= 0.0
    M[4, 4] = 1.0
    M
end

function face_normal(p1, p2, p3)
    u = to_svec3(p2) - to_svec3(p1)
    v = to_svec3(p3) - to_svec3(p1)
    n = cross(u, v)
    nn = norm(n)
    nn == 0.0 ? Vec3(0.0, 0.0, 0.0) : vec3(n / nn)
end
