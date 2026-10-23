using Test, PlantGeom, MultiScaleTreeGraph, GeometryBasics, StaticArrays, LinearAlgebra, Random, Logging

function _frame_test_tree(; shift=0, lateral=true, append=false)
    root = Node(NodeMTG(:/, :Plant, 1, 0))
    function organ(id, parent_node, relation, index)
        Node(shift + id + 100, parent_node, NodeMTG(relation, :Internode, index, 1),
            Dict{Symbol,Any}(:SourceNodeID => id, :Length => 1.0,
                :Width => 0.1, :Thickness => 0.1, :ZEuler => 0.0,
                :InsertionMode => "CENTER"))
    end
    stem = organ(11, root, :/, 1)
    next = organ(12, stem, :<, 2)
    branch = lateral ? organ(13, stem, :+, 1) : nothing
    if branch !== nothing
        branch[:YInsertionAngle] = 35.0
    end
    tail = append ? organ(14, next, :<, 3) : nothing
    return root, stem, next, branch, tail
end

function _frame_test_library(events=Any[])
    builder = function (parameters)
        push!(events, (:prototype, parameters.base_ratio))
        ExtrudedTubeGeometry([(0.0, 0.0, 0.0), (1.0, 0.0, 0.0)];
            n_sides=4, torsion=false, radii=[parameters.base_ratio, 1.0])
    end
    Dict(:Internode => ExtrusionPrototype(builder;
        defaults=(base_ratio=1.0,), attr_aliases=(base_ratio=[:BaseRatio],)))
end

function _frame_test_record(root)
    records = Any[]
    traverse!(root) do node
        geometry = get(MultiScaleTreeGraph.node_attributes(node), :geometry, nothing)
        geometry === nothing && return
        mesh = PlantGeom.geometry_to_mesh(geometry)
        push!(records, (node[:SourceNodeID],
            collect(GeometryBasics.coordinates(mesh)), collect(GeometryBasics.faces(mesh))))
    end
    return records
end

function _frame_test_rebuild(root, library, cache=nothing; kwargs...)
    rebuild_geometry!(root, library;
        reconstruction_cache=cache, bump_scene=false,
        amap_options=AmapReconstructionOptions(
            allometry_enabled=false, auto_compute_branching_order=false,
            verticil_mode=:none), verticil_mode=:none, kwargs...)
    return _frame_test_record(root)
end

@testset "Frame reuse and dependency invalidation" begin
    cache = ReconstructionFrameCache()
    library = _frame_test_library()
    input = _frame_test_tree()
    expected = _frame_test_rebuild(deepcopy(input[1]), library)
    @test isequal(_frame_test_rebuild(input[1], library, cache), expected)
    @test reconstruction_frame_cache_stats(cache).last.prefix_misses == 3
    @test reconstruction_frame_cache_stats(cache).entries == 3

    # A completely new disposable view has different node IDs and identities.
    fresh = _frame_test_tree(shift=1000)
    @test isequal(_frame_test_rebuild(fresh[1], library, cache), expected)
    @test reconstruction_frame_cache_stats(cache).last.prefix_hits == 3
    @test reconstruction_frame_cache_stats(cache).last.postfix_hits == 3

    for (which, attr, value) in ((2, :Length, 1.7), (2, :Width, 0.35),
                                (2, :YInsertionAngle, 45.0),
                                (4, :Length, 0.4), (4, :BaseRatio, 0.6))
        changed = _frame_test_tree(shift=2000)
        changed[which][attr] = value
        expected = _frame_test_rebuild(deepcopy(changed[1]), library)
        @test isequal(_frame_test_rebuild(changed[1], library, cache), expected)
    end

    # New endpoints and removed owners must invalidate/prune their dependencies.
    expanded = _frame_test_tree(append=true)
    @test isequal(_frame_test_rebuild(expanded[1], library, cache),
        _frame_test_rebuild(deepcopy(expanded[1]), library))
    @test reconstruction_frame_cache_stats(cache).entries == 4
    pruned = _frame_test_tree(lateral=false)
    @test isequal(_frame_test_rebuild(pruned[1], library, cache),
        _frame_test_rebuild(deepcopy(pruned[1]), library))
    @test reconstruction_frame_cache_stats(cache).entries == 2
    @test reconstruction_frame_cache_stats(cache).last.evictions == 2
    empty!(cache)
    @test reconstruction_frame_cache_stats(cache).entries == 0
    @test all(iszero, values(reconstruction_frame_cache_stats(cache).total))
end


@testset "Successor invalidation follows its decomposition anchor" begin
    cache = ReconstructionFrameCache()
    library = _frame_test_library()
    function anchored_tree(length)
        tree = _frame_test_tree()
        tree[2][:Length] = length
        anchor_successor = Node(200, tree[1], NodeMTG(:<, :Internode, 9, 1),
            Dict{Symbol,Any}(:SourceNodeID => 99, :Length => 0.5,
                :Width => 0.1, :Thickness => 0.1, :ZEuler => 0.0))
        return tree[1]
    end
    _frame_test_rebuild(anchored_tree(1.0), library, cache)
    changed = anchored_tree(1.8)
    @test isequal(_frame_test_rebuild(changed, library, cache),
        _frame_test_rebuild(deepcopy(changed), library))
    @test reconstruction_frame_cache_stats(cache).last.prefix_misses > 0
end

@testset "Hooks and prototype callbacks always execute in order" begin
    cache = ReconstructionFrameCache()
    angle = Ref(0.0)
    rotation_angle = Ref(0.0)
    function run_cached(cache)
        events = Any[]
        rng = Xoshiro(17)
        tree = _frame_test_tree()
        hook = function (node, rotation, _axis)
            # A real draw and callback side effect must occur even when
            # the incoming and final cached frames agree exactly.
            push!(events, (:hook,
                get(MultiScaleTreeGraph.node_attributes(node), :SourceNodeID, 0),
                rand(rng)))
            node[:DeviationAngle] = angle[]
            return rotation * SMatrix{3,3,Float64}(PlantGeom.RotX(rotation_angle[]))
        end
        selector = function (node)
            push!(events, (:selector, get(MultiScaleTreeGraph.node_attributes(node), :SourceNodeID, 0)))
            return nothing
        end
        rebuild_geometry!(tree[1], _frame_test_library(events);
            reconstruction_cache=cache, bump_scene=false,
            prototype_selector=selector, verticil_mode=:none,
            amap_options=AmapReconstructionOptions(
                allometry_enabled=false, auto_compute_branching_order=false,
                frame_orientation_hook=hook, verticil_mode=:none))
        return _frame_test_record(tree[1]), events, ntuple(_ -> rand(rng), 8)
    end
    expected = run_cached(nothing)
    @test isequal(run_cached(cache), expected)
    @test isequal(run_cached(cache), expected)
    @test reconstruction_frame_cache_stats(cache).last.prefix_hits == 3
    @test reconstruction_frame_cache_stats(cache).last.postfix_hits == 3
    angle[] = 20.0
    expected = run_cached(nothing)
    @test isequal(run_cached(cache), expected)
    @test reconstruction_frame_cache_stats(cache).last.postfix_misses > 0
    rotation_angle[] = 0.2
    expected = run_cached(nothing)
    @test isequal(run_cached(cache), expected)
    @test reconstruction_frame_cache_stats(cache).last.postfix_misses > 0
end

@testset "Callback geometry mutation cannot poison frame reuse" begin
    cache = ReconstructionFrameCache()
    library = _frame_test_library()
    first = _frame_test_tree()
    _frame_test_rebuild(first[1], library, cache)
    first[2][:geometry].path[1] = (100.0, 200.0, 300.0)
    first[2][:geometry].radii[1] = 123.0
    fresh = _frame_test_tree()
    @test isequal(_frame_test_rebuild(fresh[1], library, cache),
        _frame_test_rebuild(deepcopy(fresh[1]), library))
    @test reconstruction_frame_cache_stats(cache).last.prefix_hits == 3
end

@testset "Fallbacks and error cleanup" begin
    cache = ReconstructionFrameCache()
    tree = _frame_test_tree()
    _frame_test_rebuild(tree[1], _frame_test_library(), cache)
    duplicate = _frame_test_tree()
    duplicate[3][:SourceNodeID] = duplicate[2][:SourceNodeID]
    @test isequal(_frame_test_rebuild(duplicate[1], _frame_test_library(), cache),
        _frame_test_rebuild(deepcopy(duplicate[1]), _frame_test_library()))
    @test reconstruction_frame_cache_stats(cache).entries == 0
    @test reconstruction_frame_cache_stats(cache).last.fallbacks == 4

    nested = _frame_test_tree()
    component = Node(nested[3], NodeMTG(:/, :Internode, 4, 2))
    component[:SourceNodeID] = 50
    component[:Length] = 0.3
    component[:ZEuler] = 0.0
    @test isequal(_frame_test_rebuild(nested[1], _frame_test_library(), cache),
        _frame_test_rebuild(deepcopy(nested[1]), _frame_test_library()))
    @test reconstruction_frame_cache_stats(cache).entries == 0

    _frame_test_rebuild(_frame_test_tree()[1], _frame_test_library(), cache)
    @test_throws ErrorException rebuild_geometry!(_frame_test_tree()[1],
        _frame_test_library(); reconstruction_cache=cache,
        prototype_selector=node -> error("callback fixture"))
    @test reconstruction_frame_cache_stats(cache).entries == 0
    @test all(iszero, values(reconstruction_frame_cache_stats(cache).total))
    @test_throws ArgumentError rebuild_geometry!(_frame_test_tree()[1],
        _frame_test_library(); reconstruction_cache=1)
end

Base.@noinline function _frame_test_retained_cache()
    tree = _frame_test_tree()
    refs = WeakRef[]
    traverse!(node -> push!(refs, WeakRef(node)), tree[1])
    cache = ReconstructionFrameCache()
    _frame_test_rebuild(tree[1], _frame_test_library(), cache)
    return refs, cache
end

@testset "Frame cache owns values rather than source nodes" begin
    refs, cache = _frame_test_retained_cache()
    GC.gc(true)
    GC.gc(true)
    @test reconstruction_frame_cache_stats(cache).entries == 3
    @test all(ref -> ref.value === nothing, refs)
    empty!(cache)
    @test reconstruction_frame_cache_stats(cache).entries == 0
end

@testset "Coordinate, warnings, and constraint fallbacks" begin
    cache = ReconstructionFrameCache()
    library = _frame_test_library()
    function coordinate_run(cache)
        tree = _frame_test_tree()
        tree[2][:XX] = 0.0
        tree[2][:YY] = 0.0
        tree[2][:ZZ] = 0.0
        tree[3][:XX] = 1.0
        tree[3][:YY] = 0.2
        tree[3][:ZZ] = 0.0
        rebuild_geometry!(tree[1], library; reconstruction_cache=cache,
            amap_options=AmapReconstructionOptions(
                coordinate_delegate_mode=:explicit_rewire_previous,
                allometry_enabled=false, auto_compute_branching_order=false),
            bump_scene=false)
        return _frame_test_record(tree[1])
    end
    @test isequal(coordinate_run(cache), coordinate_run(nothing))
    @test reconstruction_frame_cache_stats(cache).entries == 0
    @test reconstruction_frame_cache_stats(cache).last.fallbacks == 4

    # Full warning behavior is retained by opting this whole call out.
    warning_output = IOBuffer()
    with_logger(SimpleLogger(warning_output, Logging.Warn)) do
        rebuild_geometry!(_frame_test_tree()[1], library;
            reconstruction_cache=cache, warn_missing=true, bump_scene=false)
    end
    @test position(warning_output) > 0
    @test reconstruction_frame_cache_stats(cache).entries == 0

    function constrained_run(cache)
        tree = _frame_test_tree()
        hook = function (node, rotation, _axis)
            if !isroot(node)
                node[:GeometricalConstraint] = Dict{Symbol,Any}(
                    :type => :plane, :normal => (0.0, 0.0, 1.0), :d => 0.0)
            end
            return rotation
        end
        rebuild_geometry!(tree[1], library; reconstruction_cache=cache,
            amap_options=AmapReconstructionOptions(
                frame_orientation_hook=hook,
                allometry_enabled=false, auto_compute_branching_order=false),
            bump_scene=false)
        return _frame_test_record(tree[1])
    end
    @test isequal(constrained_run(cache), constrained_run(nothing))
    @test isequal(constrained_run(cache), constrained_run(nothing))
    @test reconstruction_frame_cache_stats(cache).last.postfix_hits == 0
end

@testset "Sibling topology changes invalidate phyllotaxy" begin
    library = _frame_test_library()
    cache = ReconstructionFrameCache()
    function siblings_run(two, cache)
        tree = _frame_test_tree()
        if two
            other = Node(900, tree[2], NodeMTG(:+, :Internode, 2, 1),
                Dict{Symbol,Any}(:SourceNodeID => 90, :Length => 0.6,
                    :Width => 0.1, :Thickness => 0.1, :ZEuler => 0.0,
                    :YInsertionAngle => 35.0, :InsertionMode => "CENTER"))
        end
        rebuild_geometry!(tree[1], library; reconstruction_cache=cache,
            amap_options=AmapReconstructionOptions(
                allometry_enabled=false, auto_compute_branching_order=false),
            bump_scene=false)
        return _frame_test_record(tree[1])
    end
    siblings_run(false, cache)
    @test isequal(siblings_run(true, cache), siblings_run(true, nothing))
    @test reconstruction_frame_cache_stats(cache).last.prefix_misses >= 2
end
