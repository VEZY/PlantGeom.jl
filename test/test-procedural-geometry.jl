@testset "procedural geometry sources" begin
    mtg = Node(NodeMTG("/", "Plant", 1, 1))
    static_node = Node(mtg, NodeMTG("/", "Internode", 1, 2))
    procedural_node = Node(mtg, NodeMTG("/", "Internode", 2, 2))

    static_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            0.05,
        ),
    )
    static_node[:geometry] = PlantGeom.Geometry(
        ref_mesh=RefMesh("StaticCylinder", static_mesh),
    )

    procedural_node[:geometry] = ExtrudedTubeGeometry(
        [
            Point(0.0, 0.0, 0.0),
            Point(0.3, 0.04, 0.0),
            Point(0.7, 0.08, 0.02),
            Point(1.0, 0.10, 0.03),
        ];
        n_sides=10,
        radius=0.06,
        torsion=false,
        cap_ends=true,
        material=RGB(0.2, 0.5, 0.7),
        transformation=PlantGeom.Translation(2.0, 0.0, 0.0),
    )

    procedural_mesh = refmesh_to_mesh(procedural_node)
    @test nelements(procedural_mesh) > 0
    @test minimum(p[1] for p in GeometryBasics.coordinates(procedural_mesh)) > 1.8

    batches, selected = PlantGeom.compile_geometry_jobs(mtg)
    @test selected
    @test length(batches.static) == 1
    @test length(batches.generic) == 1

    meshes, node_ids, ne_per_mesh = PlantGeom.materialize_geometry_jobs(batches)
    @test length(meshes) == 2
    @test length(node_ids) == 2
    @test length(ne_per_mesh) == 2

    expected_ids = Set([
        MultiScaleTreeGraph.node_id(static_node),
        MultiScaleTreeGraph.node_id(procedural_node),
    ])
    @test Set(node_ids) == expected_ids

    merged_mesh, face2node = PlantGeom.build_merged_mesh_with_map(mtg)
    @test nelements(merged_mesh) == length(face2node)
    @test Set(face2node) == expected_ids
end
