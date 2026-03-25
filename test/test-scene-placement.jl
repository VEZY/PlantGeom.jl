_approx_scene_value(a::Number, b::Number; atol=1e-10) = isapprox(Float64(a), Float64(b); atol=atol)

function _approx_scene_value(a::AbstractArray, b::AbstractArray; atol=1e-10)
    length(a) == length(b) || return false
    all(_approx_scene_value(x, y; atol=atol) for (x, y) in zip(a, b))
end

_approx_scene_value(a, b; atol=1e-10) = a == b

function _approx_scene_mesh(a, b; atol=1e-10)
    GeometryBasics.faces(a) == GeometryBasics.faces(b) || return false
    _approx_scene_value(GeometryBasics.coordinates(a), GeometryBasics.coordinates(b); atol=atol)
end

function _scene_test_generated_plant()
    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    axis = emit_internode!(plant; index=1, link=:/, length=0.25, width=0.03, bump_scene=false)
    emit_leaf!(axis; index=1, length=0.11, width=0.035, y_insertion_angle=55.0, bump_scene=false)

    stem_ref = RefMesh(
        "stem",
        GeometryBasics.mesh(
            GeometryBasics.Cylinder(
                Point(0.0, 0.0, 0.0),
                Point(1.0, 0.0, 0.0),
                0.1,
            ),
        ),
    )
    leaf_ref = RefMesh(
        "leaf",
        GeometryBasics.Mesh(
            [Point(0.0, -0.1, 0.0), Point(0.0, 0.1, 0.0), Point(1.0, 0.0, 0.0)],
            [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
        ),
        RGB(0.2, 0.6, 0.25),
    )

    rebuild_geometry!(
        plant,
        Dict(
            :Internode => RefMeshPrototype(stem_ref, true),
            :Leaf => RefMeshPrototype(leaf_ref, false),
        );
        bump_scene=false,
    )

    return plant
end

function _scene_object_meshes(scene)
    [
        [refmesh_to_mesh(node) for node in MultiScaleTreeGraph.traverse(child, n -> n, filter_fun=PlantGeom.has_geometry)]
        for child in children(scene)
    ]
end

@testset "place_in_scene!: mixed scene round-trip through OPS" begin
    imported = read_opf("files/simple_plant.opf", attr_type=Dict, mtg_type=NodeMTG)
    generated = _scene_test_generated_plant()

    scene = Node(NodeMTG(:/, :Scene, 1, 0))
    scene.scene_dimensions = (
        GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0),
        GeometryBasics.Point{3,Float64}(20.0, 20.0, 0.0),
    )

    place_in_scene!(
        imported;
        scene=scene,
        scene_id=1,
        plant_id=1,
        functional_group="imported",
        pos=GeometryBasics.Point{3,Float64}(1.0, 2.0, 0.0),
        rotation=0.25,
    )
    place_in_scene!(
        generated;
        scene=scene,
        scene_id=1,
        plant_id=2,
        functional_group="generated",
        pos=GeometryBasics.Point{3,Float64}(4.0, 1.5, 0.0),
        scale=1.4,
        rotation=-0.15,
        inclination_angle=0.2,
    )

    @test length(children(scene)) == 2
    @test all(hasproperty(child, :scene_transformation) for child in children(scene))
    @test [child.plantID for child in children(scene)] == [1, 2]

    meshes_before = _scene_object_meshes(scene)

    mktempdir() do tmp
        out_ops = joinpath(tmp, "mixed_scene.ops")
        @test_nowarn write_ops(out_ops, scene)

        reloaded = read_ops(out_ops)
        @test reloaded.scene_dimensions == scene.scene_dimensions
        @test [child.sceneID for child in children(reloaded)] == [1, 1]
        @test [child.plantID for child in children(reloaded)] == [1, 2]
        @test [child.functional_group for child in children(reloaded)] == ["imported", "generated"]
        @test [child.pos for child in children(reloaded)] == [
            GeometryBasics.Point{3,Float64}(1.0, 2.0, 0.0),
            GeometryBasics.Point{3,Float64}(4.0, 1.5, 0.0),
        ]

        meshes_after = _scene_object_meshes(reloaded)
        @test length(meshes_before) == length(meshes_after)

        for (before_group, after_group) in zip(meshes_before, meshes_after)
            @test length(before_group) == length(after_group)
            @test all(_approx_scene_mesh(a, b) for (a, b) in zip(before_group, after_group))
        end
    end
end
