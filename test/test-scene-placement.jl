_approx_scene_value(a::Number, b::Number; atol=1e-10) = isapprox(Float64(a), Float64(b); atol=atol)

function _approx_scene_value(a::AbstractArray, b::AbstractArray; atol=1e-10)
    length(a) == length(b) || return false
    all(_approx_scene_value(x, y; atol=atol) for (x, y) in zip(a, b))
end

function _scene_child_xranges(mtg)
    map(children(mtg)) do child
        xmins = Float64[]
        xmaxs = Float64[]
        traverse!(child, filter_fun=PlantGeom.has_geometry) do node
            push!(xmins, Float64(xmin(node)))
            push!(xmaxs, Float64(xmax(node)))
            true
        end
        (minimum(xmins), maximum(xmaxs))
    end
end

@testset "make_scene: configurable MTG encoding type" begin
    imported = read_opf("files/simple_plant.opf", mtg_type=MutableNodeMTG)

    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0); mtg_type=MutableNodeMTG) do builder
        add_plant!(builder, imported; group="imported", id=1)
    end

    @test MultiScaleTreeGraph.node_mtg(scene.mtg) isa MutableNodeMTG
    @test all(child -> MultiScaleTreeGraph.node_mtg(child) isa MutableNodeMTG, children(scene.mtg))
    @test length(children(scene.mtg)) == 1
end

@testset "make_scene: path adders use scene MTG encoding type" begin
    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, "files/simple_plant.opf"; group="imported", id=1)
    end

    @test MultiScaleTreeGraph.node_mtg(scene.mtg) isa NodeMTG
    @test all(child -> MultiScaleTreeGraph.node_mtg(child) isa NodeMTG, children(scene.mtg))
    @test length(children(scene.mtg)) == 1
end

@testset "make_scene: repeated objects receive unique node ids" begin
    imported = read_opf("files/simple_plant.opf", mtg_type=NodeMTG)

    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, imported; group="imported", id=1, at=(0.25, 0.5, 0.0))
        add_plant!(builder, imported; group="imported", id=2, at=(1.25, 0.5, 0.0), rotate=(z=30.0,), deg=true)
    end

    ids = MultiScaleTreeGraph.traverse(scene.mtg, MultiScaleTreeGraph.node_id)
    @test length(unique(ids)) == length(ids)
    @test [child.object_id for child in children(scene.mtg)] == [1, 2]
    @test !isempty(scene.nodes)

    child_xranges = _scene_child_xranges(scene.mtg)
    @test child_xranges[2][1] > child_xranges[1][2]
    @test all(hasproperty(child, :pos) for child in children(scene.mtg))
    @test all(hasproperty(child, :scene_transformation) for child in children(scene.mtg))
    @test children(scene.mtg)[2].rotation ≈ deg2rad(30.0)

    imported_source_ids = descendants(imported, :source_topology_id; ignore_nothing=true, self=true)
    source_ids = [
        descendants(child, :source_topology_id; ignore_nothing=true, self=true) for child in children(scene.mtg)
    ]
    @test source_ids == [imported_source_ids, imported_source_ids]

    mktempdir() do tmp
        out_ops = joinpath(tmp, "repeated_objects.ops")
        @test_nowarn write_ops(out_ops, scene.mtg)
        reloaded = read_ops(out_ops)
        reloaded_source_ids = [
            descendants(child, :source_topology_id; ignore_nothing=true, self=true) for child in children(reloaded)
        ]
        @test reloaded_source_ids == source_ids
        reloaded_xranges = _scene_child_xranges(reloaded)
        @test reloaded_xranges[2][1] > reloaded_xranges[1][2]
    end
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

@testset "scene placement: deprecated pos keyword" begin
    old_transform = scene_object_transformation(; pos=(1.0, 2.0, 0.0), scale=1.2)
    new_transform = scene_object_transformation(; at=(1.0, 2.0, 0.0), scale=1.2)
    @test old_transform(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0)) ==
          new_transform(GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0))

    plant = _scene_test_generated_plant()
    place_in_scene!(plant; plant_id=1, pos=(1.0, 1.0, 0.0), apply_transform=false)
    @test plant.pos == GeometryBasics.Point{3,Float64}(1.0, 1.0, 0.0)
end

function _scene_object_meshes(scene)
    [
        [refmesh_to_mesh(node) for node in MultiScaleTreeGraph.traverse(child, n -> n, filter_fun=PlantGeom.has_geometry)]
        for child in children(scene)
    ]
end

@testset "place_in_scene!: mixed scene round-trip through OPS" begin
    imported = read_opf("files/simple_plant.opf", mtg_type=NodeMTG)
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
        at=GeometryBasics.Point{3,Float64}(1.0, 2.0, 0.0),
        rotation=0.25,
    )
    place_in_scene!(
        generated;
        scene=scene,
        scene_id=1,
        plant_id=2,
        functional_group="generated",
        at=GeometryBasics.Point{3,Float64}(4.0, 1.5, 0.0),
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
