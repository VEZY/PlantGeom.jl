using BenchmarkTools
using GeometryBasics
using MultiScaleTreeGraph
using PlantGeom
using PlantSimEngine

const SOURCE_OWNER_MAP_COMPONENTS_PER_OWNER = 3
const SOURCE_OWNER_MAP_OWNER_ID_OFFSET = 100_000_000

function source_owner_map_benchmark_mesh()
    GeometryBasics.Mesh(
        GeometryBasics.Point{3,Float64}[
            GeometryBasics.Point(0.0, 0.0, 0.0),
            GeometryBasics.Point(1.0, 0.0, 0.0),
            GeometryBasics.Point(0.0, 1.0, 0.0),
        ],
        GeometryBasics.TriangleFace{Int}[
            GeometryBasics.TriangleFace{Int}(1, 2, 3),
        ],
    )
end

function source_owner_map_nearest_leaf(node)
    current = node
    while MultiScaleTreeGraph.symbol(current) !== :Leaf
        MultiScaleTreeGraph.isroot(current) && error("No Leaf owner found")
        current = MultiScaleTreeGraph.parent(current)
    end
    return current
end

function source_owner_map_source_plant(
    n_owners::Int;
    components_per_owner::Int=SOURCE_OWNER_MAP_COMPONENTS_PER_OWNER,
)
    shared_ref = RefMesh("source-owner-map-component", source_owner_map_benchmark_mesh())
    plant = Node(1, NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    next_node_id = 2

    for owner_index in 1:n_owners
        leaf = Node(
            next_node_id,
            plant,
            NodeMTG(:+, :Leaf, owner_index, 2),
            Dict{Symbol,Any}(
                # Keep botanical owner ids disjoint from scene-copy ids so this
                # fixture exercises exact source identity rather than raw-id
                # coincidence.
                :source_topology_id => SOURCE_OWNER_MAP_OWNER_ID_OFFSET + owner_index,
            ),
        )
        next_node_id += 1

        for component_index in 1:components_per_owner
            Node(
                next_node_id,
                leaf,
                NodeMTG(:+, :Leaflet, component_index, 3),
                Dict{Symbol,Any}(
                    :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
                ),
            )
            next_node_id += 1
        end
    end
    return plant
end

function source_owner_map_status(node)
    return PlantSimEngine.Status(node=node)
end

function source_owner_map_runtime(root)
    model = PlantSimEngine.CompositeModel(
        root;
        id=MultiScaleTreeGraph.node_id,
        status=source_owner_map_status,
    )
    PlantSimEngine.Advanced.refresh_bindings!(model)
    return model
end

function source_owner_map_fixture(
    n_owners::Int;
    components_per_owner::Int=SOURCE_OWNER_MAP_COMPONENTS_PER_OWNER,
)
    source_root = source_owner_map_source_plant(
        n_owners;
        components_per_owner=components_per_owner,
    )
    scene = make_scene(
        domain=(0.0, 0.0, 2.0, 2.0),
        compute_area=false,
        compute_barycenter=false,
    ) do builder
        add_plant!(
            builder,
            source_root;
            group="plants",
            id=1,
            source_owner=source_owner_map_nearest_leaf,
        )
    end

    exact_runtime = source_owner_map_runtime(scene.mtg)

    runtime_root = Node(
        2 + n_owners * (components_per_owner + 1),
        NodeMTG(:/, :Scene, 1, 0),
        Dict{Symbol,Any}(),
    )
    MultiScaleTreeGraph.addchild!(runtime_root, source_root)
    explicit_runtime = source_owner_map_runtime(runtime_root)
    source_roots = (1 => source_root,)

    exact_map = compile_source_owner_map(scene, exact_runtime)
    explicit_map = compile_source_owner_map(
        scene,
        explicit_runtime;
        source_roots=source_roots,
    )

    # Lifecycle measurements mutate only this copy. The hot-path maps above
    # remain current regardless of benchmark execution order.
    lifecycle_scene = deepcopy(scene)

    return (
        n_owners=n_owners,
        components_per_owner=components_per_owner,
        scene=scene,
        exact_runtime=exact_runtime,
        explicit_runtime=explicit_runtime,
        source_roots=source_roots,
        exact_map=exact_map,
        explicit_map=explicit_map,
        first_key=first(keys(exact_map)),
        lifecycle_scene=lifecycle_scene,
    )
end

@inline source_owner_map_lookup(owner_map, key) = owner_map[key]

@inline source_owner_map_fresh(owner_map, scene, runtime) =
    source_owner_map_iscurrent(owner_map, scene, runtime)

function source_owner_map_lifecycle_rebuild(scene, runtime, source_roots)
    bump_scene_version!(scene.mtg)
    return compile_source_owner_map(
        scene,
        runtime;
        source_roots=source_roots,
    )
end

function source_owner_map_smoke(fixture)
    exact_map = compile_source_owner_map(fixture.scene, fixture.exact_runtime)
    explicit_map = compile_source_owner_map(
        fixture.scene,
        fixture.explicit_runtime;
        source_roots=fixture.source_roots,
    )
    @assert length(exact_map) == fixture.n_owners
    @assert collect(keys(exact_map)) == collect(keys(explicit_map))
    @assert source_owner_map_fresh(exact_map, fixture.scene, fixture.exact_runtime)
    @assert source_owner_map_fresh(explicit_map, fixture.scene, fixture.explicit_runtime)

    source_owner_map_lookup(exact_map, fixture.first_key)
    source_owner_map_fresh(exact_map, fixture.scene, fixture.exact_runtime)
    lookup_allocations = @allocated source_owner_map_lookup(exact_map, fixture.first_key)
    freshness_allocations = @allocated source_owner_map_fresh(
        exact_map,
        fixture.scene,
        fixture.exact_runtime,
    )

    lifecycle_map = source_owner_map_lifecycle_rebuild(
        fixture.lifecycle_scene,
        fixture.explicit_runtime,
        fixture.source_roots,
    )
    @assert source_owner_map_fresh(
        lifecycle_map,
        fixture.lifecycle_scene,
        fixture.explicit_runtime,
    )

    return (
        owners=length(exact_map),
        components=length(fixture.scene.nodes),
        lookup_allocations=lookup_allocations,
        freshness_allocations=freshness_allocations,
    )
end

const SOURCE_OWNER_MAP_1K = source_owner_map_fixture(1_000)
const SOURCE_OWNER_MAP_10K = source_owner_map_fixture(10_000)

const SOURCE_OWNER_MAP_SUITE = BenchmarkGroup()
for (label, fixture) in (
    "1k owners, 3 components each" => SOURCE_OWNER_MAP_1K,
    "10k owners, 3 components each" => SOURCE_OWNER_MAP_10K,
)
    fixture_suite = BenchmarkGroup()
    fixture_suite["compile, exact scene"] = @benchmarkable compile_source_owner_map(
        $fixture.scene,
        $fixture.exact_runtime,
    ) evals = 1
    fixture_suite["compile, explicit source roots"] = @benchmarkable compile_source_owner_map(
        $fixture.scene,
        $fixture.explicit_runtime;
        source_roots=$fixture.source_roots,
    ) evals = 1
    fixture_suite["getindex, compiled map"] = @benchmarkable source_owner_map_lookup(
        $fixture.exact_map,
        $fixture.first_key,
    )
    fixture_suite["freshness, compiled map"] = @benchmarkable source_owner_map_fresh(
        $fixture.exact_map,
        $fixture.scene,
        $fixture.exact_runtime,
    )
    fixture_suite["lifecycle barrier, invalidate and rebuild"] =
        @benchmarkable source_owner_map_lifecycle_rebuild(
            $fixture.lifecycle_scene,
            $fixture.explicit_runtime,
            $fixture.source_roots,
        ) evals = 1
    SOURCE_OWNER_MAP_SUITE[label] = fixture_suite
end

if abspath(PROGRAM_FILE) == @__FILE__
    for fixture in (SOURCE_OWNER_MAP_1K, SOURCE_OWNER_MAP_10K)
        smoke = source_owner_map_smoke(fixture)
        @assert smoke.lookup_allocations == 0
        @assert smoke.freshness_allocations == 0
    end
    BenchmarkTools.tune!(SOURCE_OWNER_MAP_SUITE)
    display(BenchmarkTools.run(SOURCE_OWNER_MAP_SUITE; verbose=true))
end
