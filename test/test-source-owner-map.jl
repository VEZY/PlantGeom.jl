function _source_owner_map_status(node)
    return PlantSimEngine.Status(node=node)
end

function _source_owner_map_runtime(root; id=MultiScaleTreeGraph.node_id)
    model = PlantSimEngine.CompositeModel(
        root;
        id=id,
        status=_source_owner_map_status,
    )
    PlantSimEngine.Advanced.refresh_bindings!(model)
    for object in PlantSimEngine.model_objects(model)
        status = PlantSimEngine.model_status(model, object)
        @test status === object.status
        @test PlantSimEngine.source_node(model, status) === status.node
        @test !haskey(
            MultiScaleTreeGraph.node_attributes(status.node),
            :plantsimengine_status,
        )
    end
    return model
end

function _source_owner_map_simple_scene(source_node_id::Int=401)
    first_plant, _ = _ownership_test_plant(source_node_id)
    second_plant, _ = _ownership_test_plant(source_node_id)
    return make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        add_plant!(builder, first_plant; group="plants", id=1)
        add_plant!(builder, second_plant; group="plants", id=2, at=(2.0, 0.0, 0.0))
    end
end

function _source_owner_map_leaf_nodes(scene)
    return [
        only(_ownership_geometry_nodes(root)) for
        root in MultiScaleTreeGraph.children(scene.mtg)
    ]
end

_source_owner_lookup_allocated(owner_map, key) = @allocated owner_map[key]
_source_owner_current_allocated(owner_map, scene, runtime) =
    @allocated source_owner_map_iscurrent(owner_map, scene, runtime)

@testset "PlantSimEngine source-owner map: exact scene identity" begin
    scene = _source_owner_map_simple_scene(401)
    id_accessor = node -> Symbol(:scene_object_, MultiScaleTreeGraph.node_id(node))
    runtime = _source_owner_map_runtime(scene.mtg; id=id_accessor)
    owner_map = compile_source_owner_map(scene, runtime)

    expected_keys = [SourceOwnerKey(1, 401), SourceOwnerKey(2, 401)]
    scene_leaves = _source_owner_map_leaf_nodes(scene)
    expected_ids = PlantSimEngine.object_id.(Ref(runtime), scene_leaves)

    @test collect(keys(owner_map)) == expected_keys
    @test collect(values(owner_map)) == expected_ids
    @test collect(owner_map) == collect(expected_keys .=> expected_ids)
    @test length(owner_map) == 2
    @test all(haskey(owner_map, key) for key in expected_keys)
    @test owner_map[expected_keys[1]] == expected_ids[1]
    @test owner_map[expected_keys[2]] == expected_ids[2]
    @test expected_ids[1].value == id_accessor(scene_leaves[1])
    @test expected_ids[2].value == id_accessor(scene_leaves[2])
    @test_throws MethodError setindex!(owner_map, expected_ids[1], expected_keys[1])

    # Warm both public hot lookups before measuring their steady-state path.
    _source_owner_lookup_allocated(owner_map, expected_keys[1])
    _source_owner_current_allocated(owner_map, scene, runtime)
    @test _source_owner_lookup_allocated(owner_map, expected_keys[1]) == 0
    @test _source_owner_current_allocated(owner_map, scene, runtime) == 0
    @test source_owner_map_iscurrent(owner_map)
    @test scene_version(scene) == scene_version(scene.mtg)

    subset = compile_source_owner_map(
        scene,
        runtime;
        owner_keys=(expected_keys[2], expected_keys[2]),
    )
    @test collect(keys(subset)) == expected_keys[2:2]
    @test only(values(subset)) == expected_ids[2]
end

@testset "PlantSimEngine source-owner map: raw mesh owner anchor" begin
    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_object!(
            builder,
            _ownership_test_mesh();
            group="plants",
            type="Leaf",
            id=11,
        )
    end
    runtime = _source_owner_map_runtime(scene.mtg)
    source_root = only(MultiScaleTreeGraph.children(scene.mtg))
    scene_leaf = only(MultiScaleTreeGraph.children(source_root))
    owner_key = SourceOwnerKey(1, 2)

    # The wrapper's current scene id collides with the Leaf's retained source
    # id, but only the stamped Leaf is an exact source-owner destination.
    @test PlantGeom._stored_source_ownership(source_root) === nothing
    @test PlantGeom._intrinsic_source_node_id(source_root) == owner_key.source_node_id
    @test PlantGeom._stored_source_ownership(scene_leaf) ==
          PlantGeom._SceneSourceOwnership(1, 2, 2)

    owner_map = compile_source_owner_map(scene, runtime)
    leaf_object_id = PlantSimEngine.object_id(runtime, scene_leaf)
    root_object_id = PlantSimEngine.object_id(runtime, source_root)

    @test collect(owner_map) == [owner_key => leaf_object_id]
    @test owner_map[owner_key] == leaf_object_id
    @test owner_map[owner_key] != root_object_id
end

@testset "PlantSimEngine source-owner map: compound organs" begin
    shared_ref = RefMesh("source-map-compound", _ownership_test_mesh())
    source_plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    source_leaf = Node(
        2,
        source_plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(:source_topology_id => 410),
    )
    for (node_id, source_node_id) in ((3, 411), (4, 412))
        Node(
            node_id,
            source_leaf,
            NodeMTG(:+, :Leaflet, node_id - 2, 3),
            Dict{Symbol,Any}(
                :source_topology_id => source_node_id,
                :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
            ),
        )
    end
    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            source_plant;
            group="plants",
            id=1,
            source_owner=_nearest_leaf_owner,
        )
    end
    runtime = _source_owner_map_runtime(
        scene.mtg;
        id=node -> Symbol(:compound_, MultiScaleTreeGraph.node_id(node)),
    )
    owner_map = compile_source_owner_map(scene, runtime)
    scene_root = only(MultiScaleTreeGraph.children(scene.mtg))
    scene_leaf = only(_ownership_nodes_by_symbol(scene_root, :Leaf))

    @test length(scene.nodes) == 2
    @test collect(keys(owner_map)) == [SourceOwnerKey(1, 410)]
    @test only(values(owner_map)) == PlantSimEngine.object_id(runtime, scene_leaf)
end

function _source_owner_map_external_sources()
    shared_ref = RefMesh("source-map-external", _ownership_test_mesh())
    first_plant = Node(10, NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    first_leaf = Node(
        11,
        first_plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(
            :source_topology_id => 420,
            :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
        ),
    )
    second_plant = Node(20, NodeMTG(:/, :Plant, 2, 1), Dict{Symbol,Any}())
    second_leaf = Node(
        21,
        second_plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(
            :source_topology_id => 420,
            :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
        ),
    )

    scene = make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        add_plant!(builder, first_plant; group="plants", id=1)
        add_plant!(builder, second_plant; group="plants", id=2, at=(2.0, 0.0, 0.0))
    end

    foreign_first = deepcopy(first_plant)
    runtime_root = Node(1, NodeMTG(:/, :Scene, 1, 0), Dict{Symbol,Any}())
    MultiScaleTreeGraph.addchild!(runtime_root, first_plant)
    MultiScaleTreeGraph.addchild!(runtime_root, second_plant)
    id_accessor = node -> Symbol(
        lowercase(string(MultiScaleTreeGraph.symbol(node))),
        :_,
        MultiScaleTreeGraph.node_id(node),
    )
    runtime = _source_owner_map_runtime(runtime_root; id=id_accessor)
    return (
        scene=scene,
        runtime=runtime,
        roots=Dict(1 => first_plant, 2 => second_plant),
        leaves=(first_leaf, second_leaf),
        foreign_first=foreign_first,
    )
end

@testset "PlantSimEngine source-owner map: explicit roots and resolver" begin
    fixture = _source_owner_map_external_sources()
    scene = fixture.scene
    runtime = fixture.runtime
    expected_keys = [SourceOwnerKey(1, 420), SourceOwnerKey(2, 420)]
    expected_ids = collect(PlantSimEngine.object_id.(Ref(runtime), fixture.leaves))

    @test_throws ArgumentError compile_source_owner_map(scene, runtime)

    rooted = compile_source_owner_map(
        scene,
        runtime;
        source_roots=fixture.roots,
    )
    @test collect(keys(rooted)) == expected_keys
    @test collect(values(rooted)) == expected_ids

    raw_ids = Dict(key => id.value for (key, id) in zip(expected_keys, expected_ids))
    callback = compile_source_owner_map(
        scene,
        runtime;
        object_resolver=key -> raw_ids[key],
    )
    @test collect(values(callback)) == expected_ids

    coalesced = compile_source_owner_map(
        scene,
        runtime;
        object_resolver=_ -> expected_ids[1].value,
    )
    @test collect(values(coalesced)) == fill(expected_ids[1], 2)

    subset = compile_source_owner_map(
        scene,
        runtime;
        owner_keys=expected_keys[1],
        source_roots=Dict(1 => fixture.roots[1]),
    )
    @test collect(subset) == [expected_keys[1] => expected_ids[1]]

    @test_throws ArgumentError compile_source_owner_map(
        scene,
        runtime;
        source_roots=fixture.roots,
        object_resolver=identity,
    )
    @test_throws ArgumentError compile_source_owner_map(
        scene,
        runtime;
        source_roots=Dict(1 => fixture.roots[1]),
    )
    @test_throws ArgumentError compile_source_owner_map(
        scene,
        runtime;
        source_roots=Dict(1 => fixture.foreign_first, 2 => fixture.roots[2]),
    )
    @test_throws ArgumentError compile_source_owner_map(
        scene,
        runtime;
        object_resolver=_ -> :not_a_registered_object,
    )

    empty_map = compile_source_owner_map(
        scene,
        runtime;
        owner_keys=SourceOwnerKey[],
        source_roots=Dict{Int,MultiScaleTreeGraph.Node}(),
    )
    @test isempty(empty_map)
end

@testset "PlantSimEngine source-owner map: lifecycle freshness and atomic errors" begin
    scene = _source_owner_map_simple_scene(430)
    runtime = _source_owner_map_runtime(scene.mtg)
    owner_map = compile_source_owner_map(scene, runtime)
    owner_keys = collect(keys(owner_map))
    owner_ids = collect(values(owner_map))

    @test source_owner_map_iscurrent(owner_map, scene, runtime)
    @test source_owner_map_iscurrent(owner_map)

    other_scene = _source_owner_map_simple_scene(430)
    @test !source_owner_map_iscurrent(owner_map, other_scene, runtime)
    other_runtime = _source_owner_map_runtime(scene.mtg; id=node -> Symbol(:other_, node_id(node)))
    @test !source_owner_map_iscurrent(owner_map, scene, other_runtime)

    bump_scene_version!(scene.mtg)
    @test !source_owner_map_iscurrent(owner_map, scene, runtime)
    @test !source_owner_map_iscurrent(owner_map)

    refreshed_map = compile_source_owner_map(scene, runtime)
    scene_root_id = PlantSimEngine.object_id(runtime, scene.mtg)
    PlantSimEngine.register_object!(
        runtime,
        PlantSimEngine.Object(
            :source_owner_dynamic_object;
            scale=:Leaf,
            parent=scene_root_id,
            status=PlantSimEngine.Status(signal=0.0),
        ),
    )
    @test !source_owner_map_iscurrent(refreshed_map, scene, runtime)
    @test !source_owner_map_iscurrent(refreshed_map)
    @test_throws ArgumentError compile_source_owner_map(scene, runtime)

    PlantSimEngine.Advanced.refresh_bindings!(runtime)
    current_map = compile_source_owner_map(scene, runtime)
    @test source_owner_map_iscurrent(current_map, scene, runtime)

    result = Ref{Any}(:unchanged)
    calls = Ref(0)
    failing_resolver = key -> begin
        calls[] += 1
        calls[] == 1 && return owner_ids[1]
        error("deliberate resolver failure")
    end
    scene_revision_before = scene_version(scene)
    model_revision_before = PlantSimEngine.Advanced.model_revision(runtime)
    @test_throws ErrorException begin
        result[] = compile_source_owner_map(
            scene,
            runtime;
            object_resolver=failing_resolver,
        )
    end
    @test result[] === :unchanged
    @test calls[] == 2
    @test scene_version(scene) == scene_revision_before
    @test PlantSimEngine.Advanced.model_revision(runtime) == model_revision_before
    @test !PlantSimEngine.Advanced.bindings_dirty(runtime)

    resolver_calls = Ref(0)
    @test_throws ArgumentError compile_source_owner_map(
        scene,
        runtime;
        owner_keys=SourceOwnerKey(99, 99),
        object_resolver=key -> begin
            resolver_calls[] += 1
            owner_ids[1]
        end,
    )
    @test resolver_calls[] == 0

    version_mutating_resolver = key -> begin
        key == owner_keys[end] && bump_scene_version!(scene.mtg)
        owner_ids[1]
    end
    @test_throws ErrorException compile_source_owner_map(
        scene,
        runtime;
        object_resolver=version_mutating_resolver,
    )
end
