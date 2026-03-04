@testset "write_gwa root geometry round-trip preserves plane area" begin
    pts = [
        PlantGeom.point3(0.0, 0.0, 0.0),
        PlantGeom.point3(1.0, 0.0, 0.0),
        PlantGeom.point3(1.0, 1.0, 0.0),
        PlantGeom.point3(0.0, 1.0, 0.0),
    ]
    faces = [
        PlantGeom.face3(1, 2, 3),
        PlantGeom.face3(1, 3, 4),
    ]
    plane_mesh = PlantGeom._mesh(pts, faces)
    ref_mesh = RefMesh("plane", plane_mesh)

    mtg = Node(MutableNodeMTG(:/, :Plane, 1, 1), MultiScaleTreeGraph.init_empty_attr())
    mtg.geometry = PlantGeom.Geometry(ref_mesh=ref_mesh)

    mktempdir() do tmp
        out = joinpath(tmp, "plane.gwa")
        @test_nowarn write_gwa(out, mtg)
        roundtrip = @test_nowarn read_gwa(out)
        @test length(children(roundtrip)) == 1

        node = first(children(roundtrip))
        mesh = refmesh_to_mesh(node)
        verts = GeometryBasics.coordinates(mesh)
        tris = GeometryBasics.faces(mesh)
        area = 0.0
        for tri in tris
            a, b, c = verts[tri[1]], verts[tri[2]], verts[tri[3]]
            area += norm(cross(b - a, c - a)) / 2
        end

        @test area ≈ 1.0 atol = 1e-12
    end
end
