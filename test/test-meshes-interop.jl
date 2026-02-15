using GeometryBasics
using PlantGeom
using Meshes
using Unitful

vertices = [
    PlantGeom.Point3(0.0, 0.0, 0.0),
    PlantGeom.Point3(1.0, 0.0, 0.0),
    PlantGeom.Point3(0.0, 1.0, 0.0),
]
faces = [GeometryBasics.TriangleFace{Int}(1, 2, 3)]
mesh_gb = GeometryBasics.Mesh(vertices, faces)

mesh_meshes = to_meshes(mesh_gb)
@test mesh_meshes isa Meshes.SimpleMesh
@test length(collect(Meshes.vertices(mesh_meshes))) == 3
@test length(collect(Meshes.elements(Meshes.topology(mesh_meshes)))) == 1

mesh_gb_roundtrip = to_geometrybasics(mesh_meshes)
@test PlantGeom.nvertices(mesh_gb_roundtrip) == 3
@test PlantGeom.nelements(mesh_gb_roundtrip) == 1
roundtrip_vertices = GeometryBasics.decompose(PlantGeom.Point3, mesh_gb_roundtrip)
@test roundtrip_vertices[2][1] ≈ 1.0
@test roundtrip_vertices[3][2] ≈ 1.0

ref = RefMesh("triangle", mesh_gb, RGB(0.2, 0.4, 0.6))
ref_as_meshes = to_meshes(ref)
@test ref_as_meshes isa Meshes.SimpleMesh
@test length(collect(Meshes.vertices(ref_as_meshes))) == PlantGeom.nvertices(ref)

mesh_with_units = Meshes.SimpleMesh(
    [
        Meshes.Point(0.0u"m", 0.0u"m", 0.0u"m"),
        Meshes.Point(1.0u"m", 0.0u"m", 0.0u"m"),
        Meshes.Point(0.0u"m", 1.0u"m", 0.0u"m"),
    ],
    [
        Meshes.connect((1, 2, 3), Meshes.Triangle),
    ],
)
mesh_gb_from_units = to_geometrybasics(mesh_with_units)
verts_from_units = GeometryBasics.decompose(PlantGeom.Point3, mesh_gb_from_units)
@test verts_from_units[1][1] isa Float64
@test verts_from_units[2][1] ≈ 1.0
@test verts_from_units[3][2] ≈ 1.0
