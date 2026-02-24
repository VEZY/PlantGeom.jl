module PlantGeomMeshesInterop

using PlantGeom
import PlantGeom: to_meshes, to_geometrybasics
import GeometryBasics
import Meshes
import Unitful

@inline _to_meter_float(x::Unitful.AbstractQuantity) = Float64(Unitful.ustrip(Unitful.u"m", x))
@inline _to_meter_float(x) = Float64(x)

"""
    to_meshes(mesh::GeometryBasics.AbstractMesh{3})

Convert a GeometryBasics triangular mesh (meters, unitless `Float64`) to `Meshes.SimpleMesh`.
"""
function to_meshes(mesh::GeometryBasics.AbstractMesh{3})
    vertices = GeometryBasics.decompose(GeometryBasics.Point{3,Float64}, mesh)
    points = [Meshes.Point(v[1], v[2], v[3]) for v in vertices]

    faces = GeometryBasics.decompose(GeometryBasics.TriangleFace{Int}, mesh)
    connectivities = [Meshes.connect((Int(f[1]), Int(f[2]), Int(f[3])), Meshes.Triangle) for f in faces]

    return Meshes.SimpleMesh(points, connectivities)
end

"""
    to_meshes(ref_mesh::PlantGeom.RefMesh)

Convert the geometry carried by a `RefMesh` to `Meshes.SimpleMesh`.
"""
to_meshes(ref_mesh::PlantGeom.RefMesh) = to_meshes(ref_mesh.mesh)

"""
    to_geometrybasics(mesh::Meshes.SimpleMesh)

Convert a Meshes triangular mesh to a `GeometryBasics.Mesh` using unitless meters.
"""
function to_geometrybasics(mesh::Meshes.SimpleMesh)
    vertices = GeometryBasics.Point{3,Float64}[]
    for p in Meshes.vertices(mesh)
        c = Meshes.coords(p)
        push!(vertices, GeometryBasics.Point{3,Float64}(_to_meter_float(c.x), _to_meter_float(c.y), _to_meter_float(c.z)))
    end

    topology = Meshes.topology(mesh)
    elems = collect(Meshes.elements(topology))
    faces = GeometryBasics.TriangleFace{Int}[]
    for elem in elems
        idx = Int.(Tuple(elem.indices))
        length(idx) == 3 || error("Only triangular meshes can be converted to GeometryBasics.")
        push!(faces, GeometryBasics.TriangleFace{Int}(idx[1], idx[2], idx[3]))
    end

    return GeometryBasics.Mesh(vertices, faces)
end

end
