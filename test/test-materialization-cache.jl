using Test, PlantGeom, MultiScaleTreeGraph, GeometryBasics, StaticArrays, LinearAlgebra

function _cache_test_tube(; path=[(0.0, 0.0, 0.0), (1.0, 0.0, 0.0)], kwargs...)
    ExtrudedTubeGeometry(path; n_sides=6, torsion=false, kwargs...)
end

function _cache_test_exact(root, cache; kwargs...)
    expected, expected_owners = PlantGeom.build_merged_mesh_with_map(root; kwargs...)
    actual, actual_owners = PlantGeom.build_merged_mesh_with_map(
        root; materialization_cache=cache, kwargs...,
    )
    @test isequal(GeometryBasics.coordinates(actual), GeometryBasics.coordinates(expected))
    @test isequal(GeometryBasics.faces(actual), GeometryBasics.faces(expected))
    @test actual_owners == expected_owners
    return actual, actual_owners
end

struct _CacheTestStatefulTransform <: PlantGeom.Transformation
    calls::Base.RefValue{Int}
end

struct _CacheTestFailedGeometry end
PlantGeom.geometry_to_mesh(::_CacheTestFailedGeometry) = error("materialization failure fixture")

const _CACHE_TEST_EXTERNAL_OFFSET = Ref(0.0)
const _CACHE_TEST_EXTERNAL_CONVERSIONS = Ref(0)
struct _CacheTestExternalReal <: Real
    value::Float64
end
function Base.Float64(value::_CacheTestExternalReal)
    _CACHE_TEST_EXTERNAL_CONVERSIONS[] += 1
    return value.value + _CACHE_TEST_EXTERNAL_OFFSET[]
end

mutable struct _CacheTestMutableRadius <: Real
    value::Float64
end
Base.Float64(value::_CacheTestMutableRadius) = value.value

Base.@noinline function _cache_test_weak_tree()
    root = Node(NodeMTG(:/, :Plant, 1, 1))
    organ = Node(root, NodeMTG(:/, :Internode, 1, 2))
    organ[:geometry] = _cache_test_tube()
    cache = GeometryMaterializationCache()
    PlantGeom.build_merged_mesh_with_map(root; materialization_cache=cache)
    return WeakRef(root), cache
end

@testset "Only trusted numeric representations are reusable" begin
    root = Node(NodeMTG(:/, :Plant, 1, 1))
    organ = Node(root, NodeMTG(:/, :Internode, 1, 2))
    cache = GeometryMaterializationCache()

    # An isbits Real can still consult external state during conversion.
    # Rejected inputs must not be converted while checking their cache key.
    path = [(_CacheTestExternalReal(0.0), 0.0, 0.0),
            (_CacheTestExternalReal(1.0), 0.0, 0.0)]
    organ[:geometry] = _cache_test_tube(path=path)
    _CACHE_TEST_EXTERNAL_OFFSET[] = 0.0
    _CACHE_TEST_EXTERNAL_CONVERSIONS[] = 0
    @test PlantGeom._materialization_signature(organ[:geometry]) ===
          PlantGeom._UNSUPPORTED_MATERIALIZATION_INPUT
    @test _CACHE_TEST_EXTERNAL_CONVERSIONS[] == 0
    before, _ = _cache_test_exact(root, cache)
    initial_conversions = _CACHE_TEST_EXTERNAL_CONVERSIONS[]
    @test initial_conversions > 0
    _CACHE_TEST_EXTERNAL_OFFSET[] = 0.4
    after, _ = _cache_test_exact(root, cache)
    @test _CACHE_TEST_EXTERNAL_CONVERSIONS[] == 2initial_conversions
    @test GeometryBasics.coordinates(before) != GeometryBasics.coordinates(after)
    @test materialization_cache_stats(cache).last.fallbacks == 1
    @test materialization_cache_stats(cache).entries == 0
    _CACHE_TEST_EXTERNAL_OFFSET[] = 0.0

    # The positional struct constructor can bypass the keyword constructor's
    # Float64 normalization. A mutable radius must never alias a cached key.
    template = _cache_test_tube()
    radius = _CacheTestMutableRadius(0.2)
    organ[:geometry] = ExtrudedTubeGeometry(
        template.path, template.n_sides, radius, template.radii,
        template.widths, template.heights, template.path_normals,
        template.torsion, template.cap_ends, template.material,
        template.transformation,
    )
    @test PlantGeom._materialization_signature(organ[:geometry]) ===
          PlantGeom._UNSUPPORTED_MATERIALIZATION_INPUT
    before, _ = _cache_test_exact(root, cache)
    radius.value = 0.5
    after, _ = _cache_test_exact(root, cache)
    @test GeometryBasics.coordinates(before) != GeometryBasics.coordinates(after)
    @test materialization_cache_stats(cache).last.fallbacks == 1
    @test materialization_cache_stats(cache).entries == 0
end

function (transform::_CacheTestStatefulTransform)(point)
    transform.calls[] += 1
    return point + SVector(0.0, 0.0, 0.1)
end

@testset "Incremental organ materialization and exact invalidation" begin
    root = Node(NodeMTG(:/, :Plant, 1, 1))
    first = Node(root, NodeMTG(:/, :Internode, 1, 2))
    last = Node(first, NodeMTG(:<, :Internode, 2, 2))
    first[:geometry] = _cache_test_tube()
    last[:geometry] = _cache_test_tube(transformation=PlantGeom.Translation(1.0, 0.0, 0.0))
    cache = GeometryMaterializationCache()
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last ==
          (hits=0, misses=2, fallbacks=0, evictions=0)

    # Independently rebuilt geometry objects are reusable; object identity is
    # not a cache key, and mutating the returned merge cannot corrupt the cache.
    first[:geometry] = _cache_test_tube()
    merged, owners = _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last.hits == 2
    GeometryBasics.coordinates(merged)[1] = Point(100.0, 100.0, 100.0)
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last.hits == 2
    @test unique(owners) == [MultiScaleTreeGraph.node_id(first), MultiScaleTreeGraph.node_id(last)]

    # Diameter, support-frame translation, mutable coefficients and shape data
    # each invalidate exactly the affected organ.
    path = [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0)]
    radii = [0.5, 1.0]
    linear = Matrix{Float64}(I, 3, 3)
    shift = [0.0, 0.0, 0.0]
    first[:geometry] = _cache_test_tube(
        path=path, radius=0.2, radii=radii,
        transformation=PlantGeom.AffineMap(linear, shift),
    )
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last.misses == 1
    for mutate! in (
        () -> (radii[1] = 0.75),
        () -> (path[2] = (1.2, 0.0, 0.0)),
        () -> (linear[1, 1] = 1.1),
        () -> (shift[3] = 0.3),
    )
        mutate!()
        _cache_test_exact(root, cache)
        @test materialization_cache_stats(cache).last.hits == 1
        @test materialization_cache_stats(cache).last.misses == 1
    end

    # A parent/support geometry change must not implicitly invalidate an
    # unrelated mesh whose fully resolved geometry is unchanged.
    first[:geometry] = _cache_test_tube(cap_ends=true)
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last ==
          (hits=1, misses=1, fallbacks=0, evictions=0)

    # Geometry removed by pruning or excluded by selection is released.
    last[:geometry] = nothing
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).entries == 1
    @test materialization_cache_stats(cache).last.evictions == 1
    last[:geometry] = _cache_test_tube()
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last.misses == 1
    _cache_test_exact(root, cache; filter_fun=node -> node === last)
    @test materialization_cache_stats(cache).entries == 1
    @test materialization_cache_stats(cache).last.evictions == 1

    @test empty!(cache) === cache
    @test materialization_cache_stats(cache) == (
        entries=0,
        last=(hits=0, misses=0, fallbacks=0, evictions=0),
        total=(hits=0, misses=0, fallbacks=0, evictions=0),
    )
end

@testset "Unsupported geometry and stateful transforms retain full behavior" begin
    root = Node(NodeMTG(:/, :Plant, 1, 1))
    tube = Node(root, NodeMTG(:/, :Internode, 1, 2))
    trailing = Node(root, NodeMTG(:/, :Leaf, 2, 2))
    tube[:geometry] = _cache_test_tube()
    reference_mesh = GeometryBasics.Mesh(
        Point3f[(0, 0, 0), (1, 0, 0), (0, 1, 0)],
        [TriangleFace{Int}(1, 2, 3)],
    )
    trailing[:geometry] = PlantGeom.Geometry(ref_mesh=RefMesh("triangle", reference_mesh))
    cache = GeometryMaterializationCache()
    _cache_test_exact(root, cache)
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last ==
          (hits=1, misses=0, fallbacks=1, evictions=0)

    # Arbitrary transforms are never probed, flattened, or assumed pure.
    calls = Ref(0)
    tube[:geometry] = _cache_test_tube(transformation=_CacheTestStatefulTransform(calls))
    _cache_test_exact(root, cache)
    first_calls = calls[]
    @test first_calls > 0
    @test materialization_cache_stats(cache).last.fallbacks == 2
    @test materialization_cache_stats(cache).last.evictions == 1
    _cache_test_exact(root, cache)
    @test calls[] == 2first_calls
    @test materialization_cache_stats(cache).entries == 0

    # Changing the final support frame is a miss; composition order is part
    # of the signature, even when an alternative representation seems equal.
    tube[:geometry] = _cache_test_tube(transformation=PlantGeom.ComposedTransformation(
        PlantGeom.Translation(0.1, 0.2, 0.3),
        PlantGeom.LinearMap(SMatrix{3,3,Float64}(I)),
    ))
    _cache_test_exact(root, cache)
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last.hits == 1
    @test materialization_cache_stats(cache).last.fallbacks == 1
    tube[:geometry] = _cache_test_tube(transformation=PlantGeom.ComposedTransformation(
        PlantGeom.Translation(0.1, 0.2, 0.3),
        PlantGeom.LinearMap(PlantGeom.RotZ(0.3)),
    ))
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last.misses == 1
end

@testset "Cache ambiguity, failure, identifier reuse, and tree lifetime" begin
    root = Node(NodeMTG(:/, :Plant, 1, 1))
    organ = Node(root, NodeMTG(:/, :Internode, 1, 2))
    organ[:geometry] = _cache_test_tube()
    cache = GeometryMaterializationCache()
    _cache_test_exact(root, cache)
    previous_total = materialization_cache_stats(cache).total
    organ[:geometry] = _CacheTestFailedGeometry()
    @test_throws r"materialization failure fixture" PlantGeom.build_merged_mesh_with_map(
        root; materialization_cache=cache,
    )
    @test materialization_cache_stats(cache).entries == 0
    @test materialization_cache_stats(cache).total == previous_total
    @test materialization_cache_stats(cache).last ==
          (hits=0, misses=0, fallbacks=0, evictions=0)

    # Identifiers reused after a scope switch cannot produce a stale mesh.
    organ[:geometry] = _cache_test_tube(radius=0.3)
    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).last.misses == 1

    # Ambiguous identifiers can occur in externally prepared job batches.
    # Columnar MTGs correctly forbid constructing such a topology directly.
    batches, _ = PlantGeom.compile_geometry_jobs(root)
    PlantGeom._compile_node_geometry_jobs!(
        batches, 2, MultiScaleTreeGraph.node_id(organ), _cache_test_tube(radius=0.7),
    )
    full_meshes, full_ids, full_sizes, full_order = PlantGeom._materialize_geometry_jobs(batches)
    cached_meshes, cached_ids, cached_sizes, cached_order =
        PlantGeom._materialize_geometry_jobs(batches, cache)
    @test cached_ids == full_ids
    @test cached_sizes == full_sizes
    @test cached_order == full_order
    for (actual, expected) in zip(cached_meshes, full_meshes)
        @test isequal(GeometryBasics.coordinates(actual), GeometryBasics.coordinates(expected))
        @test isequal(GeometryBasics.faces(actual), GeometryBasics.faces(expected))
    end
    @test materialization_cache_stats(cache).last ==
          (hits=0, misses=0, fallbacks=2, evictions=1)
    @test materialization_cache_stats(cache).entries == 0

    _cache_test_exact(root, cache)
    @test materialization_cache_stats(cache).entries == 1
    organ[:geometry] = nothing
    @test_throws ErrorException PlantGeom.build_merged_mesh_with_map(
        root; materialization_cache=cache,
    )
    @test materialization_cache_stats(cache).entries == 0

    tree_reference, live_cache = _cache_test_weak_tree()
    GC.gc(true)
    GC.gc(true)
    @test tree_reference.value === nothing
    @test materialization_cache_stats(live_cache).entries == 1
end
