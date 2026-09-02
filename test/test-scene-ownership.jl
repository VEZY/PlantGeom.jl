function _ownership_test_mesh()
    GeometryBasics.Mesh(
        GeometryBasics.Point{3,Float64}[
            GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0),
            GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0),
            GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0),
        ],
        GeometryBasics.TriangleFace{Int}[
            GeometryBasics.TriangleFace{Int}(1, 2, 3),
        ],
    )
end

function _ownership_test_plant(source_node_id::Int; ref_mesh=RefMesh("owner", _ownership_test_mesh()))
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    leaf = Node(
        2,
        plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(
            :source_topology_id => source_node_id,
            :geometry => PlantGeom.Geometry(ref_mesh=ref_mesh),
        ),
    )
    return plant, leaf
end

function _ownership_geometry_nodes(root)
    MultiScaleTreeGraph.traverse(
        root,
        identity;
        filter_fun=PlantGeom.has_geometry,
    )
end

function _ownership_nodes_by_symbol(root, node_symbol::Symbol)
    MultiScaleTreeGraph.traverse(
        root,
        identity;
        filter_fun=node -> MultiScaleTreeGraph.symbol(node) === node_symbol,
    )
end

function _nearest_leaf_owner(node)
    current = node
    while MultiScaleTreeGraph.symbol(current) != :Leaf
        MultiScaleTreeGraph.isroot(current) && error("No Leaf owner found")
        current = MultiScaleTreeGraph.parent(current)
    end
    return current
end

@testset "scene ownership: Scene roots are geometry-free containers" begin
    scene_root = Node(
        NodeMTG(:/, :Scene, 1, 0),
        Dict{Symbol,Any}(
            :geometry => PlantGeom.Geometry(
                ref_mesh=RefMesh("invalid-scene-geometry", _ownership_test_mesh()),
            ),
        ),
    )

    @test_throws ArgumentError prepare_scene(scene_root)
    @test !haskey(scene_root, :_scene_source_instance_id)
end

@testset "scene ownership: duplicate raw ids remain distinct" begin
    plant_a, source_leaf_a = _ownership_test_plant(41)
    plant_b, source_leaf_b = _ownership_test_plant(41)

    scene = make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        # Deliberately repeat public object metadata: ownership must not depend on it.
        add_plant!(builder, plant_a; group="plants", id=1)
        add_plant!(builder, plant_b; group="plants", id=1, at=(2.0, 0.0, 0.0))
    end

    scene_leaf_ids = [
        MultiScaleTreeGraph.node_id(only(_ownership_geometry_nodes(child))) for
        child in MultiScaleTreeGraph.children(scene.mtg)
    ]
    owners = source_owner.(Ref(scene), scene_leaf_ids)

    @test owners == [SourceOwnerKey(1, 41), SourceOwnerKey(2, 41)]
    @test owners[1] != owners[2]
    @test [scene_node(scene, id).source_topology_id for id in scene_leaf_ids] == [41, 41]
    @test scene.face2node isa Vector{Int}
    @test Set(scene.face2node) == Set(scene_leaf_ids)
    @test source_owners(scene) == Dict(id => owner for (id, owner) in zip(scene_leaf_ids, owners))
    @test !haskey(source_leaf_a, :_scene_source_instance_id)
    @test !haskey(source_leaf_b, :_scene_source_instance_id)
end

@testset "scene ownership: repeated instancing receives a fresh namespace" begin
    plant, _ = _ownership_test_plant(57)

    scene = make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        add_plant!(builder, plant; group="plants", id=7)
        add_plant!(
            builder,
            plant;
            group="plants",
            id=7,
            at=(2.0, 0.5, 0.0),
            rotate=(z=35.0,),
            deg=true,
        )
    end

    scene_leaf_ids = [
        MultiScaleTreeGraph.node_id(only(_ownership_geometry_nodes(child))) for
        child in MultiScaleTreeGraph.children(scene.mtg)
    ]
    @test source_owner(scene, scene_leaf_ids[1]) == SourceOwnerKey(1, 57)
    @test source_owner(scene, scene_leaf_ids[2]) == SourceOwnerKey(2, 57)
end

@testset "scene ownership: compatibility builders continue existing namespaces" begin
    plant_a, _ = _ownership_test_plant(61)
    plant_b, _ = _ownership_test_plant(61)
    scene = make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        add_plant!(builder, plant_a; group="plants", id=1)
    end

    inferred_builder = SceneBuilder(
        scene.mtg,
        scene.scene_xy_bounds,
        scene.source_path,
        true,
        true,
        true,
    )
    @test inferred_builder.next_source_instance_id == 2

    builder = SceneBuilder(
        scene.mtg,
        scene.scene_xy_bounds,
        scene.source_path,
        true,
        true,
        true,
        MultiScaleTreeGraph.max_id(scene.mtg) + 1,
    )
    add_plant!(builder, plant_b; group="plants", id=1, at=(2.0, 0.0, 0.0))
    extended = prepare_scene(builder.mtg; source_path=builder.source_path)
    scene_leaf_ids = MultiScaleTreeGraph.node_id.(_ownership_geometry_nodes(extended.mtg))
    owners = source_owner.(Ref(extended), scene_leaf_ids)

    @test owners == [SourceOwnerKey(1, 61), SourceOwnerKey(2, 61)]

    exhausted = Node(NodeMTG(:/, :Scene, 1, 0), Dict{Symbol,Any}())
    exhausted[:_scene_source_instance_id] = typemax(Int)
    @test_throws OverflowError SceneBuilder(
        exhausted,
        nothing,
        "overflow.scene",
        true,
        true,
        true,
    )
end

@testset "scene ownership: shared RefMesh does not own identity" begin
    shared_ref = RefMesh("shared-owner-mesh", _ownership_test_mesh())
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    for (node_id, source_node_id) in ((2, 71), (3, 72))
        Node(
            node_id,
            plant,
            NodeMTG(:+, :Leaf, node_id - 1, 2),
            Dict{Symbol,Any}(
                :source_topology_id => source_node_id,
                :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
            ),
        )
    end

    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, plant; group="plants", id=1)
    end
    scene_leaves = _ownership_geometry_nodes(only(MultiScaleTreeGraph.children(scene.mtg)))
    scene_leaf_ids = MultiScaleTreeGraph.node_id.(scene_leaves)
    owner_by_source_id = Dict(
        scene_node(scene, id).source_topology_id => source_owner(scene, id) for
        id in scene_leaf_ids
    )

    @test scene_leaves[1][:geometry].ref_mesh === scene_leaves[2][:geometry].ref_mesh
    @test owner_by_source_id == Dict(
        71 => SourceOwnerKey(1, 71),
        72 => SourceOwnerKey(1, 72),
    )
end

@testset "scene ownership: compound geometry resolves to its Leaf" begin
    shared_ref = RefMesh("compound-leaflet", _ownership_test_mesh())
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    leaf = Node(
        2,
        plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(:source_topology_id => 80),
    )
    for (node_id, source_node_id) in ((3, 81), (4, 82))
        Node(
            node_id,
            leaf,
            NodeMTG(:+, :Leaflet, node_id - 2, 3),
            Dict{Symbol,Any}(
                :source_topology_id => source_node_id,
                :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
            ),
        )
    end

    scene = make_scene(domain=(0.0, 0.0, 3.0, 3.0)) do builder
        add_plant!(
            builder,
            plant;
            group="plants",
            id=1,
            source_owner=_nearest_leaf_owner,
            scale=(1.2, 0.8, 1.0),
            rotate=(z=20.0,),
            deg=true,
        )
    end

    scene_leaflets = _ownership_geometry_nodes(only(MultiScaleTreeGraph.children(scene.mtg)))
    scene_leaflet_ids = MultiScaleTreeGraph.node_id.(scene_leaflets)

    @test all(id -> source_owner(scene, id) == SourceOwnerKey(1, 80), scene_leaflet_ids)
    @test sort([scene_node(scene, id).source_topology_id for id in scene_leaflet_ids]) == [81, 82]
    @test all(
        scene_node_id -> source_owner(scene, scene_node_id) == SourceOwnerKey(1, 80),
        scene.face2node,
    )
    @test source_owner(scene, typemax(Int)) === nothing
end

@testset "scene ownership: compound mappings survive re-instancing" begin
    shared_ref = RefMesh("compound-reinstance", _ownership_test_mesh())
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    leaf = Node(
        2,
        plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(:source_topology_id => 180),
    )
    for (node_id, source_node_id) in ((3, 181), (4, 182))
        Node(
            node_id,
            leaf,
            NodeMTG(:+, :Leaflet, node_id - 2, 3),
            Dict{Symbol,Any}(
                :source_topology_id => source_node_id,
                :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
            ),
        )
    end

    assembled = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            plant;
            group="plants",
            id=1,
            source_owner=_nearest_leaf_owner,
        )
    end
    assembled_root = deepcopy(only(MultiScaleTreeGraph.children(assembled.mtg)))
    MultiScaleTreeGraph.reparent!(assembled_root, nothing)

    reassembled = make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        add_plant!(builder, assembled_root; group="plants", id=1)
        add_plant!(builder, assembled_root; group="plants", id=2, at=(2.0, 0.0, 0.0))
    end
    owner_groups = [
        unique(source_owner.(Ref(reassembled), MultiScaleTreeGraph.node_id.(_ownership_geometry_nodes(root))))
        for root in MultiScaleTreeGraph.children(reassembled.mtg)
    ]

    @test owner_groups == [[SourceOwnerKey(1, 180)], [SourceOwnerKey(2, 180)]]
    for (root, expected_instance) in zip(MultiScaleTreeGraph.children(reassembled.mtg), (1, 2))
        owner_node = only(_ownership_nodes_by_symbol(root, :Leaf))
        @test PlantGeom._stored_source_owner_key(owner_node) ==
              SourceOwnerKey(expected_instance, 180)
    end

    recomputed = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            assembled_root;
            group="plants",
            id=3,
            source_owner=_ -> 777,
        )
    end
    @test unique(values(source_owners(recomputed))) == [SourceOwnerKey(1, 777)]
end

@testset "scene ownership: retained resolver covers new geometry" begin
    shared_ref = RefMesh("compound-growth", _ownership_test_mesh())
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    leaf = Node(
        2,
        plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(),
    )
    Node(
        3,
        leaf,
        NodeMTG(:+, :Leaflet, 1, 3),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=shared_ref)),
    )

    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            plant;
            group="plants",
            id=1,
            source_owner=_nearest_leaf_owner,
        )
    end
    scene_root = only(MultiScaleTreeGraph.children(scene.mtg))
    scene_leaf = only(_ownership_nodes_by_symbol(scene_root, :Leaf))
    original_owner = only(values(source_owners(scene)))

    new_leaflet = Node(
        MultiScaleTreeGraph.max_id(scene.mtg) + 1,
        scene_leaf,
        NodeMTG(:+, :Leaflet, 2, 3),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=shared_ref)),
    )
    refreshed = prepare_scene(scene.mtg; source_path=scene.source_path)
    new_leaflet_id = MultiScaleTreeGraph.node_id(new_leaflet)

    @test original_owner == SourceOwnerKey(1, 2)
    @test source_owner(refreshed, new_leaflet_id) == original_owner
    @test all(==(original_owner), values(source_owners(refreshed)))
    @test PlantGeom._stored_source_owner_key(scene_leaf) == original_owner
end

@testset "scene ownership: cascaded resolvers use intrinsic source ids" begin
    shared_ref = RefMesh("cascaded-owner", _ownership_test_mesh())
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    leaf = Node(
        2,
        plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=shared_ref)),
    )
    leaflet = Node(
        3,
        leaf,
        NodeMTG(:+, :Leaflet, 1, 3),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=shared_ref)),
    )
    cascaded_owner = node -> begin
        node_symbol = MultiScaleTreeGraph.symbol(node)
        node_symbol === :Leaf && return MultiScaleTreeGraph.parent(node)
        node_symbol === :Leaflet && return MultiScaleTreeGraph.parent(node)
        return node
    end

    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            plant;
            group="plants",
            id=1,
            source_owner=cascaded_owner,
        )
    end
    scene_root = only(MultiScaleTreeGraph.children(scene.mtg))
    scene_leaf = only(_ownership_nodes_by_symbol(scene_root, :Leaf))
    scene_leaflet = only(_ownership_nodes_by_symbol(scene_root, :Leaflet))

    @test source_owner(scene, MultiScaleTreeGraph.node_id(scene_leaf)) ==
          SourceOwnerKey(1, 1)
    @test source_owner(scene, MultiScaleTreeGraph.node_id(scene_leaflet)) ==
          SourceOwnerKey(1, 2)
    @test PlantGeom._stored_source_ownership(scene_leaf).source_node_id == 2
    @test PlantGeom._stored_source_ownership(scene_leaf).owner_node_id == 1
end

@testset "scene ownership: fallback is established before relabelling" begin
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    Node(
        91,
        plant,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=RefMesh("fallback", _ownership_test_mesh()))),
    )

    first = prepare_scene(plant; relabel_ids=true)
    leaf_id = only(scene_node_ids(first))
    @test leaf_id != 91
    @test source_owner(first, leaf_id) == SourceOwnerKey(1, 91)

    second = prepare_scene(plant; relabel_ids=true)
    @test source_owner(second, only(scene_node_ids(second))) == SourceOwnerKey(1, 91)
end

@testset "scene ownership: detached stamps require their root namespace" begin
    plant, leaf = _ownership_test_plant(191)
    prepare_scene(plant)
    original_ownership = PlantGeom._stored_source_ownership(leaf)

    plant[:_scene_source_instance_id] = nothing
    @test_throws ArgumentError prepare_scene(plant)
    @test PlantGeom._stored_source_ownership(leaf) == original_ownership
    @test plant[:_scene_source_instance_id] == 1

    plant[:_scene_source_instance_id] = nothing
    ids_before_relabel = MultiScaleTreeGraph.node_id.(
        MultiScaleTreeGraph.traverse(plant, identity),
    )
    @test_throws ArgumentError prepare_scene(plant; relabel_ids=true)
    @test MultiScaleTreeGraph.node_id.(MultiScaleTreeGraph.traverse(plant, identity)) ==
          ids_before_relabel
    @test PlantGeom._stored_source_ownership(leaf) == original_ownership

    shared_ref = RefMesh("detached-compound", _ownership_test_mesh())
    compound = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    owner_leaf = Node(2, compound, NodeMTG(:+, :Leaf, 1, 2), Dict{Symbol,Any}())
    leaflet = Node(
        3,
        owner_leaf,
        NodeMTG(:+, :Leaflet, 1, 3),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=shared_ref)),
    )
    compound_scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            compound;
            group="plants",
            id=1,
            source_owner=_nearest_leaf_owner,
        )
    end
    compound_root = only(MultiScaleTreeGraph.children(compound_scene.mtg))
    compound_owner = only(_ownership_nodes_by_symbol(compound_root, :Leaf))
    compound_leaflet = only(_ownership_nodes_by_symbol(compound_root, :Leaflet))
    owner_stamp = PlantGeom._stored_source_ownership(compound_owner)
    compound_leaflet[:_scene_source_ownership] = nothing
    compound_root[:_scene_source_instance_id] = nothing

    @test_throws ArgumentError prepare_scene(compound_root)
    @test PlantGeom._stored_source_ownership(compound_owner) == owner_stamp
    @test PlantGeom._stored_source_ownership(compound_leaflet) === nothing
end

@testset "scene ownership: direct concatenation rebases duplicate namespaces" begin
    plant, _ = _ownership_test_plant(211)
    assembled = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, plant; group="plants", id=1)
    end
    first_root = deepcopy(only(MultiScaleTreeGraph.children(assembled.mtg)))
    second_root = deepcopy(first_root)
    MultiScaleTreeGraph.reparent!(first_root, nothing)
    MultiScaleTreeGraph.reparent!(second_root, nothing)
    PlantGeom._relabel_node_ids!(
        second_root,
        Ref(MultiScaleTreeGraph.max_id(first_root) + 1),
    )

    direct_scene = Node(
        max(
            MultiScaleTreeGraph.max_id(first_root),
            MultiScaleTreeGraph.max_id(second_root),
        ) + 1,
        NodeMTG(:/, :Scene, 1, 0),
        Dict{Symbol,Any}(),
    )
    MultiScaleTreeGraph.addchild!(direct_scene, first_root)
    MultiScaleTreeGraph.addchild!(direct_scene, second_root)
    prepared = prepare_scene(direct_scene; relabel_ids=true)
    roots = MultiScaleTreeGraph.children(prepared.mtg)
    owner_groups = [
        unique(source_owner.(Ref(prepared), MultiScaleTreeGraph.node_id.(_ownership_geometry_nodes(root))))
        for root in roots
    ]

    @test owner_groups == [[SourceOwnerKey(1, 211)], [SourceOwnerKey(2, 211)]]
    @test first(owner_groups[1]).source_node_id == first(owner_groups[2]).source_node_id
end

@testset "scene ownership: cross-instance reparenting is rejected" begin
    first_plant, _ = _ownership_test_plant(251)
    second_plant, _ = _ownership_test_plant(252)
    scene = make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        add_plant!(builder, first_plant; group="plants", id=1)
        add_plant!(builder, second_plant; group="plants", id=2)
    end
    first_root, second_root = MultiScaleTreeGraph.children(scene.mtg)
    moved_leaf = only(_ownership_geometry_nodes(first_root))
    @test PlantGeom._stored_source_owner_key(moved_leaf) == SourceOwnerKey(1, 251)

    MultiScaleTreeGraph.reparent!(moved_leaf, second_root)
    @test_throws ArgumentError prepare_scene(scene.mtg)
    @test PlantGeom._stored_source_owner_key(moved_leaf) == SourceOwnerKey(1, 251)
    ids_before_relabel = MultiScaleTreeGraph.node_id.(
        MultiScaleTreeGraph.traverse(scene.mtg, identity),
    )
    @test_throws ArgumentError prepare_scene(scene.mtg; relabel_ids=true)
    @test MultiScaleTreeGraph.node_id.(MultiScaleTreeGraph.traverse(scene.mtg, identity)) ==
          ids_before_relabel
    @test PlantGeom._stored_source_owner_key(moved_leaf) == SourceOwnerKey(1, 251)
end

@testset "scene ownership: same-instance reparenting preserves identity" begin
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    first_axis = Node(2, plant, NodeMTG(:+, :Axis, 1, 2), Dict{Symbol,Any}())
    second_axis = Node(3, plant, NodeMTG(:+, :Axis, 2, 2), Dict{Symbol,Any}())
    leaf = Node(
        4,
        first_axis,
        NodeMTG(:+, :Leaf, 1, 3),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=RefMesh("same-root", _ownership_test_mesh()))),
    )
    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, plant; group="plants", id=1)
    end
    scene_root = only(MultiScaleTreeGraph.children(scene.mtg))
    scene_axes = _ownership_nodes_by_symbol(scene_root, :Axis)
    scene_leaf = only(_ownership_geometry_nodes(scene_root))
    original_owner = source_owner(scene, MultiScaleTreeGraph.node_id(scene_leaf))

    MultiScaleTreeGraph.reparent!(scene_leaf, scene_axes[2])
    refreshed = prepare_scene(scene.mtg)

    @test source_owner(refreshed, MultiScaleTreeGraph.node_id(scene_leaf)) == original_owner
    @test PlantGeom._stored_source_owner_key(scene_leaf) == original_owner
end

@testset "scene ownership: rejected compound reparenting preserves owner anchors" begin
    shared_ref = RefMesh("compound-reparent", _ownership_test_mesh())
    compound = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    leaf = Node(2, compound, NodeMTG(:+, :Leaf, 1, 2), Dict{Symbol,Any}())
    Node(
        3,
        leaf,
        NodeMTG(:+, :Leaflet, 1, 3),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=shared_ref)),
    )
    destination, _ = _ownership_test_plant(262)

    scene = make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        add_plant!(
            builder,
            compound;
            group="plants",
            id=1,
            source_owner=_nearest_leaf_owner,
        )
        add_plant!(builder, destination; group="plants", id=2)
    end
    first_root, second_root = MultiScaleTreeGraph.children(scene.mtg)
    scene_leaf = only(_ownership_nodes_by_symbol(first_root, :Leaf))
    scene_leaflet = only(_ownership_nodes_by_symbol(first_root, :Leaflet))
    @test PlantGeom._stored_source_owner_key(scene_leaf) == SourceOwnerKey(1, 2)

    MultiScaleTreeGraph.reparent!(scene_leaf, second_root)
    @test_throws ArgumentError prepare_scene(scene.mtg)
    @test PlantGeom._stored_source_owner_key(scene_leaflet) == SourceOwnerKey(1, 2)
    @test PlantGeom._stored_source_owner_key(scene_leaf) == SourceOwnerKey(1, 2)
end

@testset "scene ownership: moved owner anchor rejects new geometry" begin
    shared_ref = RefMesh("moved-anchor", _ownership_test_mesh())
    source = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    leaf = Node(2, source, NodeMTG(:+, :Leaf, 1, 2), Dict{Symbol,Any}())
    Node(
        3,
        leaf,
        NodeMTG(:+, :Leaflet, 1, 3),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=shared_ref)),
    )
    destination = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())

    scene = make_scene(domain=(0.0, 0.0, 4.0, 2.0)) do builder
        add_plant!(
            builder,
            source;
            group="plants",
            id=1,
            source_owner=_nearest_leaf_owner,
        )
        add_plant!(
            builder,
            destination;
            group="plants",
            id=2,
            source_owner=_nearest_leaf_owner,
        )
    end
    source_root, destination_root = MultiScaleTreeGraph.children(scene.mtg)
    scene_leaf = only(_ownership_nodes_by_symbol(source_root, :Leaf))
    existing_leaflet = only(_ownership_nodes_by_symbol(source_root, :Leaflet))
    MultiScaleTreeGraph.reparent!(existing_leaflet, source_root)
    MultiScaleTreeGraph.reparent!(scene_leaf, destination_root)

    # The moved Leaf is now a non-geometric owner anchor. Its stamp must still
    # be validated before any later organ is created below it.
    @test_throws ArgumentError prepare_scene(scene.mtg)
    @test PlantGeom._stored_source_owner_key(scene_leaf) == SourceOwnerKey(1, 2)
    ids_before_relabel = MultiScaleTreeGraph.node_id.(
        MultiScaleTreeGraph.traverse(scene.mtg, identity),
    )
    @test_throws ArgumentError prepare_scene(scene.mtg; relabel_ids=true)
    @test MultiScaleTreeGraph.node_id.(MultiScaleTreeGraph.traverse(scene.mtg, identity)) ==
          ids_before_relabel
    @test PlantGeom._stored_source_owner_key(scene_leaf) == SourceOwnerKey(1, 2)

    new_leaflet = Node(
        MultiScaleTreeGraph.max_id(scene.mtg) + 1,
        scene_leaf,
        NodeMTG(:+, :Leaflet, 2, 3),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=shared_ref)),
    )

    @test PlantGeom._stored_source_owner_key(scene_leaf) == SourceOwnerKey(1, 2)
    @test PlantGeom._stored_source_ownership(new_leaflet) === nothing
    @test_throws ArgumentError prepare_scene(scene.mtg)
    @test PlantGeom._stored_source_owner_key(scene_leaf) == SourceOwnerKey(1, 2)
    @test PlantGeom._stored_source_ownership(new_leaflet) === nothing
end

@testset "scene ownership: failed collision rebase is transactional" begin
    first_root, _ = _ownership_test_plant(271)
    second_root, _ = _ownership_test_plant(272)
    Node(
        3,
        second_root,
        NodeMTG(:+, :Leaf, 2, 2),
        Dict{Symbol,Any}(
            :source_topology_id => 273,
            :geometry => PlantGeom.Geometry(
                ref_mesh=RefMesh("transactional-rebase", _ownership_test_mesh()),
            ),
        ),
    )
    PlantGeom._relabel_node_ids!(
        second_root,
        Ref(MultiScaleTreeGraph.max_id(first_root) + 1),
    )
    first_root[:_scene_source_instance_id] = 1
    second_root[:_scene_source_instance_id] = 1

    resolver_calls = Ref(0)
    second_root[:_scene_source_owner_resolver] = node -> begin
        resolver_calls[] += 1
        resolver_calls[] == 1 ? node : "invalid owner"
    end
    direct_scene = Node(
        max(
            MultiScaleTreeGraph.max_id(first_root),
            MultiScaleTreeGraph.max_id(second_root),
        ) + 1,
        NodeMTG(:/, :Scene, 1, 0),
        Dict{Symbol,Any}(),
    )
    MultiScaleTreeGraph.addchild!(direct_scene, first_root)
    MultiScaleTreeGraph.addchild!(direct_scene, second_root)

    ids_before = MultiScaleTreeGraph.node_id.(
        MultiScaleTreeGraph.traverse(direct_scene, identity),
    )
    ownership_before = PlantGeom._stored_source_ownership.(
        MultiScaleTreeGraph.traverse(second_root, identity),
    )
    @test_throws ArgumentError prepare_scene(direct_scene)
    @test resolver_calls[] == 2
    @test second_root[:_scene_source_instance_id] == 1
    @test PlantGeom._stored_source_ownership.(
        MultiScaleTreeGraph.traverse(second_root, identity),
    ) == ownership_before
    @test MultiScaleTreeGraph.node_id.(MultiScaleTreeGraph.traverse(direct_scene, identity)) ==
          ids_before

    second_root[:_scene_source_owner_resolver] = identity
    prepared = prepare_scene(direct_scene)
    @test second_root[:_scene_source_instance_id] == 2
    @test all(
        key -> key.source_instance_id == 2,
        source_owner.(
            Ref(prepared),
            MultiScaleTreeGraph.node_id.(_ownership_geometry_nodes(second_root)),
        ),
    )
end

@testset "scene ownership: collision rebase rejects foreign stamps" begin
    source_root, _ = _ownership_test_plant(281)
    prepare_scene(source_root)
    first_root = deepcopy(source_root)
    second_root = deepcopy(source_root)
    PlantGeom._relabel_node_ids!(
        second_root,
        Ref(MultiScaleTreeGraph.max_id(first_root) + 1),
    )
    foreign_leaf = only(_ownership_geometry_nodes(second_root))
    foreign_ownership = PlantGeom._stored_source_ownership(foreign_leaf)
    PlantGeom._set_source_ownership!(
        foreign_leaf,
        2,
        foreign_ownership.source_node_id,
        foreign_ownership.owner_node_id,
    )

    direct_scene = Node(
        max(
            MultiScaleTreeGraph.max_id(first_root),
            MultiScaleTreeGraph.max_id(second_root),
        ) + 1,
        NodeMTG(:/, :Scene, 1, 0),
        Dict{Symbol,Any}(),
    )
    MultiScaleTreeGraph.addchild!(direct_scene, first_root)
    MultiScaleTreeGraph.addchild!(direct_scene, second_root)
    nodes = MultiScaleTreeGraph.traverse(direct_scene, identity)
    ids_before = MultiScaleTreeGraph.node_id.(nodes)
    instances_before = getindex.(
        (first_root, second_root),
        Ref(:_scene_source_instance_id),
    )
    ownership_before = PlantGeom._stored_source_ownership.(nodes)

    @test_throws ArgumentError prepare_scene(direct_scene)
    @test MultiScaleTreeGraph.node_id.(MultiScaleTreeGraph.traverse(direct_scene, identity)) ==
          ids_before
    @test getindex.(
        (first_root, second_root),
        Ref(:_scene_source_instance_id),
    ) == instances_before
    @test PlantGeom._stored_source_ownership.(
        MultiScaleTreeGraph.traverse(direct_scene, identity),
    ) == ownership_before
end

@testset "scene ownership: resolver validation and private OPF metadata" begin
    plant, _ = _ownership_test_plant(301)
    integer_owner = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, plant; group="plants", id=1, source_owner=_ -> 3001)
    end
    @test only(values(source_owners(integer_owner))) == SourceOwnerKey(1, 3001)

    @test_throws ArgumentError make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, plant; group="plants", id=1, source_owner=_ -> "Leaf")
    end
    @test_throws ArgumentError make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, plant; group="plants", id=1, source_owner=42)
    end

    foreign_plant, foreign_leaf = _ownership_test_plant(302)
    builder_ref = Ref{Any}()
    @test_throws ArgumentError make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        builder_ref[] = builder
        add_plant!(
            builder,
            plant;
            group="plants",
            id=1,
            source_owner=_ -> foreign_leaf,
        )
    end
    @test isempty(MultiScaleTreeGraph.children(builder_ref[].mtg))
    @test PlantGeom._stored_source_owner_key(foreign_leaf) === nothing
    @test PlantGeom._stored_source_owner_key(only(_ownership_geometry_nodes(plant))) === nothing

    inconsistent, inconsistent_leaf = _ownership_test_plant(303)
    prepare_scene(inconsistent)
    inconsistent[:_scene_source_instance_id] = 2
    @test_throws ArgumentError prepare_scene(inconsistent)

    mktempdir() do directory
        path = joinpath(directory, "private-metadata.opf")
        object_root = only(MultiScaleTreeGraph.children(integer_owner.mtg))
        write_opf(path, object_root)
        @test isfile(path)
        @test !occursin("_scene_", read(path, String))
    end
end


@testset "scene ownership: a valid maximal namespace does not overflow preparation" begin
    plant, leaf = _ownership_test_plant(401)
    prepare_scene(plant)
    PlantGeom._rebase_source_ownership!(plant, typemax(Int))

    scene = prepare_scene(plant)
    @test only(values(source_owners(scene))) == SourceOwnerKey(typemax(Int), 401)

    crowded = Node(NodeMTG(:/, :Scene, 1, 0), Dict{Symbol,Any}())
    retained = Node(
        2,
        crowded,
        NodeMTG(:+, :Plant, 1, 1),
        Dict{Symbol,Any}(),
    )
    raw_a = Node(
        3,
        crowded,
        NodeMTG(:+, :Plant, 2, 1),
        Dict{Symbol,Any}(),
    )
    raw_b = Node(
        4,
        crowded,
        NodeMTG(:+, :Plant, 3, 1),
        Dict{Symbol,Any}(),
    )
    retained[:_scene_source_instance_id] = typemax(Int) - 1
    @test_throws OverflowError prepare_scene(crowded)
    @test retained[:_scene_source_instance_id] == typemax(Int) - 1
    @test PlantGeom._scene_positive_int_attribute(
        raw_a,
        :_scene_source_instance_id,
    ) === nothing
    @test PlantGeom._scene_positive_int_attribute(
        raw_b,
        :_scene_source_instance_id,
    ) === nothing

    builder_root = Node(NodeMTG(:/, :Scene, 1, 0), Dict{Symbol,Any}())
    near_exhaustion = SceneBuilder(
        builder_root,
        nothing,
        "overflow.scene",
        false,
        false,
        false,
        2,
        typemax(Int) - 1,
    )
    builder_plant, _ = _ownership_test_plant(402)
    add_plant!(near_exhaustion, builder_plant; group="plants", id=1)
    @test near_exhaustion.next_source_instance_id == typemax(Int)
    children_before_overflow = length(MultiScaleTreeGraph.children(builder_root))
    @test_throws OverflowError add_plant!(
        near_exhaustion,
        builder_plant;
        group="plants",
        id=2,
    )
    @test length(MultiScaleTreeGraph.children(builder_root)) ==
          children_before_overflow
end

@testset "scene ownership: compatibility and independent retention" begin
    legacy = SceneNodeData(1.0, (0.0, 0.0, 0.0), 9)
    @test legacy.source_owner === nothing
    @test SceneNodeData{Float64}(1.0, (0.0, 0.0, 0.0), 9).source_owner === nothing
    @test sizeof(SceneNodeData{Float64}) == 80
    @test isbitstype(SourceOwnerKey)
    @test_throws ArgumentError SourceOwnerKey(0, 1)
    @test_throws ArgumentError SourceOwnerKey(1, 0)
    @test_throws ArgumentError SourceOwnerKey(-1, 1)
    @test Dict(SourceOwnerKey(1, 9) => :owner)[SourceOwnerKey(Int32(1), Int16(9))] == :owner

    plant, _ = _ownership_test_plant(91)
    scene = make_scene(
        domain=(0.0, 0.0, 2.0, 2.0),
        compute_area=false,
        compute_barycenter=false,
        source_topology_id=false,
    ) do builder
        add_plant!(builder, plant; group="plants", id=1)
    end
    scene_leaf_id = MultiScaleTreeGraph.node_id(
        only(_ownership_geometry_nodes(only(MultiScaleTreeGraph.children(scene.mtg)))),
    )
    @test scene_node(scene, scene_leaf_id).area === nothing
    @test scene_node(scene, scene_leaf_id).barycenter === nothing
    @test scene_node(scene, scene_leaf_id).source_topology_id === nothing
    @test source_owner(scene, scene_leaf_id) == SourceOwnerKey(1, 91)
end
