function _scene_units_triangle_mesh(; extent=1.0)
    GeometryBasics.Mesh(
        GeometryBasics.Point{3,Float64}[
            GeometryBasics.Point(0.0, 0.0, 0.0),
            GeometryBasics.Point(Float64(extent), 0.0, 0.0),
            GeometryBasics.Point(0.0, Float64(extent), 0.0),
        ],
        GeometryBasics.TriangleFace{Int}[
            GeometryBasics.TriangleFace{Int}(1, 2, 3),
        ],
    )
end

function _scene_units_object(geometry)
    root = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    organ = Node(
        2,
        root,
        NodeMTG(:+, :Leaf, 1, 2),
        Dict{Symbol,Any}(:geometry => geometry),
    )
    return root, organ
end

function _scene_units_geometry_node(root)
    only(MultiScaleTreeGraph.traverse(
        root,
        identity;
        filter_fun=PlantGeom.has_geometry,
    ))
end

function _scene_units_xrange(node)
    points = GeometryBasics.coordinates(refmesh_to_mesh(node))
    xs = Float64[p[1] for p in points]
    return extrema(xs)
end

function _scene_units_mesh_points(mesh)
    collect(GeometryBasics.coordinates(mesh))
end

function _scene_units_identity_map(point, _)
    point
end

function _scene_units_affine_geometry(kind::Symbol)
    translation = PlantGeom.Translation(100.0, 0.0, 0.0)
    if kind === :geometry
        ref_mesh = RefMesh("units-geometry", _scene_units_triangle_mesh(extent=100.0))
        return PlantGeom.Geometry(
            ref_mesh=ref_mesh,
            transformation=translation,
        )
    elseif kind === :point_mapped
        ref_mesh = RefMesh("units-point-map", _scene_units_triangle_mesh(extent=100.0))
        return PointMappedGeometry(
            ref_mesh,
            _scene_units_identity_map;
            params=nothing,
            transformation=translation,
        )
    elseif kind === :extruded
        return ExtrudedTubeGeometry(
            GeometryBasics.Point{3,Float64}[
                GeometryBasics.Point(0.0, 0.0, 0.0),
                GeometryBasics.Point(100.0, 0.0, 0.0),
            ];
            n_sides=4,
            radius=10.0,
            transformation=translation,
        )
    end
    error("Unknown geometry kind $kind")
end

@testset "SceneUnits: validation and accessors" begin
    metres = SceneUnits()
    centimetres = SceneUnits(length=u"cm")

    @test scene_length_unit(metres) == u"m"
    @test scene_area_unit(metres) == u"m^2"
    @test scene_length_unit(centimetres) == u"cm"
    @test scene_area_unit(centimetres) == u"cm^2"
    @test isconcretetype(SceneUnits)
    @test_throws ArgumentError SceneUnits(length=u"s")
    @test_throws ArgumentError SceneUnits(length=u"m^2")
    @test_throws ArgumentError SceneUnits(length=1.0u"m")
end

@testset "Scene units: historical constructors default to metres" begin
    root = Node(NodeMTG(:/, :Scene, 1, 0), Dict{Symbol,Any}())
    mesh = _scene_units_triangle_mesh()
    nodes = Dict{Int,SceneNodeData{Float64}}()
    face2node = Int[]

    scene = SceneGeometry(root, mesh, face2node, nodes, "legacy.scene", nothing)
    typed_scene = SceneGeometry{typeof(root),typeof(mesh),Float64}(
        root,
        mesh,
        face2node,
        nodes,
        "legacy.scene",
        nothing,
    )
    @test scene_length_unit(scene) == u"m"
    @test scene_length_unit(typed_scene) == u"m"

    builder6 = SceneBuilder(root, nothing, "legacy.scene", true, true, true)
    builder7 = SceneBuilder(root, nothing, "legacy.scene", true, true, true, 2)
    builder8 = SceneBuilder(root, nothing, "legacy.scene", true, true, true, 2, 3)
    builder_units = SceneBuilder(
        root,
        nothing,
        "centimetre.scene",
        true,
        true,
        true,
        SceneUnits(length=u"cm"),
    )
    @test all(scene_length_unit(b) == u"m" for b in (builder6, builder7, builder8))
    @test scene_length_unit(builder_units) == u"cm"
end

@testset "prepare_scene unit metadata does not rescale numeric geometry" begin
    ref_mesh = RefMesh("metadata-only", _scene_units_triangle_mesh(extent=2.0))
    object, organ = _scene_units_object(PlantGeom.Geometry(ref_mesh=ref_mesh))
    before = _scene_units_mesh_points(refmesh_to_mesh(organ))

    scene = prepare_scene(object; units=SceneUnits(length=u"cm"))
    after = _scene_units_mesh_points(refmesh_to_mesh(organ))

    @test after == before
    @test scene_length_unit(scene) == u"cm"
    @test scene_area_unit(scene) == u"cm^2"
    @test only(values(node_areas(scene))) == 2.0
    @test only(values(node_areas(scene))) isa Float64
    @test collect(only(values(node_barycenters(scene)))) ≈ [2 / 3, 2 / 3, 0.0]
    @test all(p -> all(x -> x isa Float64, p), _scene_units_mesh_points(scene.merged_mesh))

    refreshed = make_scene(
        domain=(0.0, 0.0, 10.0, 10.0),
        units=SceneUnits(length=u"cm"),
    ) do builder
        add_ground!(builder; nx=1, ny=1)
    end
    add_ground!(refreshed; nx=2, ny=1)
    @test scene_length_unit(refreshed) == u"cm"
    @test scene_area_unit(refreshed) == u"cm^2"
end

@testset "add_object! unit conversion order covers every geometry source" begin
    for kind in (:geometry, :point_mapped, :extruded)
        source, source_organ = _scene_units_object(_scene_units_affine_geometry(kind))
        source_range = _scene_units_xrange(source_organ)

        scene = make_scene(
            domain=(0.0, 0.0, 10.0, 10.0),
            units=SceneUnits(length=u"m"),
        ) do builder
            add_plant!(
                builder,
                source;
                group="plants",
                id=1,
                at=(2.0, 0.0, 0.0),
                geometry_length_unit=u"cm",
            )
        end

        copied_root = only(children(scene.mtg))
        copied_organ = _scene_units_geometry_node(copied_root)
        converted_range = _scene_units_xrange(copied_organ)

        # Existing geometry transforms are expressed in the source unit and
        # converted before the scene placement: 2 m + 100 cm = 3 m.
        @test converted_range[1] ≈ 3.0 atol = 1e-10
        @test converted_range[2] ≈ 4.0 atol = 1e-10
        @test copied_root.scene_transformation(
            GeometryBasics.Point(0.0, 0.0, 0.0),
        )[1] ≈ 2.0
        @test _scene_units_xrange(source_organ) == source_range
    end
end

@testset "add_object! converts metres to centimetre scenes" begin
    ref_mesh = RefMesh("metres", _scene_units_triangle_mesh(extent=1.0))
    source, _ = _scene_units_object(PlantGeom.Geometry(ref_mesh=ref_mesh))
    scene = make_scene(
        domain=(0.0, 0.0, 200.0, 200.0),
        units=SceneUnits(length=u"cm"),
    ) do builder
        add_object!(
            builder,
            source;
            group="objects",
            id=1,
            at=(10.0, 0.0, 0.0),
            geometry_length_unit=u"m",
        )
    end
    copied = _scene_units_geometry_node(only(children(scene.mtg)))
    @test collect(_scene_units_xrange(copied)) ≈ [10.0, 110.0]
end

@testset "same-unit and unspecified paths add no transformation layer" begin
    ref_mesh = RefMesh("identity", _scene_units_triangle_mesh())
    for geometry_length_unit in (nothing, u"m")
        source, _ = _scene_units_object(PlantGeom.Geometry(ref_mesh=ref_mesh))
        scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
            add_object!(
                builder,
                source;
                group="objects",
                id=1,
                geometry_length_unit=geometry_length_unit,
            )
        end
        copied = _scene_units_geometry_node(only(children(scene.mtg)))
        @test copied[:geometry].transformation isa PlantGeom.IdentityTransformation
        @test !(copied[:geometry].transformation isa PlantGeom.SequentialTransformation)
    end
end

@testset "later geometry is already expressed in the scene unit" begin
    source_ref = RefMesh("source-centimetres", _scene_units_triangle_mesh(extent=100.0))
    source, _ = _scene_units_object(PlantGeom.Geometry(ref_mesh=source_ref))
    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            source;
            group="plants",
            id=1,
            geometry_length_unit=u"cm",
        )
    end

    copied_root = only(children(scene.mtg))
    converted_organ = _scene_units_geometry_node(copied_root)
    emitted_ref = RefMesh("emitted-metres", _scene_units_triangle_mesh(extent=1.0))
    emitted_organ = Node(
        MultiScaleTreeGraph.max_id(scene.mtg) + 1,
        copied_root,
        NodeMTG(:+, :Leaf, 2, 2),
        Dict{Symbol,Any}(:geometry => PlantGeom.Geometry(ref_mesh=emitted_ref)),
    )

    refreshed = prepare_scene(scene.mtg; units=scene.units)
    @test collect(_scene_units_xrange(converted_organ)) ≈ [0.0, 1.0]
    @test collect(_scene_units_xrange(emitted_organ)) ≈ [0.0, 1.0]
    @test scene_length_unit(refreshed) == u"m"
end

@testset "invalid source units leave builder and source unchanged" begin
    ref_mesh = RefMesh("atomic-units", _scene_units_triangle_mesh())
    source, source_organ = _scene_units_object(PlantGeom.Geometry(ref_mesh=ref_mesh))
    root = Node(NodeMTG(:/, :Scene, 1, 0), Dict{Symbol,Any}())
    builder = SceneBuilder(
        root,
        (0.0, 0.0, 2.0, 2.0),
        "atomic.scene",
        true,
        true,
        true,
        2,
        1,
        SceneUnits(),
    )
    source_points = _scene_units_mesh_points(refmesh_to_mesh(source_organ))
    counters = (builder.next_node_id, builder.next_source_instance_id)

    @test_throws ArgumentError add_object!(
        builder,
        source;
        group="objects",
        id=1,
        geometry_length_unit=u"s",
    )
    @test isempty(children(builder.mtg))
    @test (builder.next_node_id, builder.next_source_instance_id) == counters
    @test !haskey(source, :_scene_source_instance_id)
    @test !haskey(source_organ, :_scene_source_ownership)
    @test _scene_units_mesh_points(refmesh_to_mesh(source_organ)) == source_points
end

@testset "OPF metre defaults and explicit legacy centimetres agree" begin
    metres = read_opf(
        "files/simple_plant.opf";
        attr_type=Dict,
        mtg_type=NodeMTG,
    )
    legacy_centimetres = read_opf(
        "files/simple_plant.opf";
        attr_type=Dict,
        mtg_type=NodeMTG,
        coordinate_scale=1.0,
    )

    default_scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, metres; group="plants", id=1)
    end
    explicit_metre_scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            metres;
            group="plants",
            id=1,
            geometry_length_unit=u"m",
        )
    end
    converted_legacy_scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(
            builder,
            legacy_centimetres;
            group="plants",
            id=1,
            geometry_length_unit=u"cm",
        )
    end

    expected = _scene_units_mesh_points(default_scene.merged_mesh)
    @test _scene_units_mesh_points(explicit_metre_scene.merged_mesh) ≈ expected
    @test _scene_units_mesh_points(converted_legacy_scene.merged_mesh) ≈ expected
end

@testset "GWA coordinates stay raw until an explicit scene conversion" begin
    gwa = read_gwa("files/pave1x1.gwa"; mtg_type=NodeMTG)
    raw_node = _scene_units_geometry_node(gwa)
    @test _scene_units_xrange(raw_node) == (0.0, 1.0)

    scene = make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_object!(
            builder,
            gwa;
            group="objects",
            id=1,
            geometry_length_unit=u"cm",
        )
    end
    converted = _scene_units_geometry_node(only(children(scene.mtg)))
    @test collect(_scene_units_xrange(converted)) ≈ [0.0, 0.01]
    @test _scene_units_xrange(raw_node) == (0.0, 1.0)
end

@testset "OPS removes placement but retains unit conversion" begin
    ref_mesh = RefMesh("ops-units", _scene_units_triangle_mesh(extent=100.0))
    source, _ = _scene_units_object(PlantGeom.Geometry(ref_mesh=ref_mesh))
    scene = make_scene(domain=(0.0, 0.0, 10.0, 10.0)) do builder
        add_object!(
            builder,
            source;
            group="objects",
            id=1,
            at=(2.0, 0.0, 0.0),
            geometry_length_unit=u"cm",
        )
    end
    before = _scene_units_xrange(_scene_units_geometry_node(only(children(scene.mtg))))

    mktempdir() do tmp
        path = joinpath(tmp, "units.ops")
        write_ops(path, scene.mtg)
        reloaded = read_ops(path; mtg_type=NodeMTG)
        after = _scene_units_xrange(
            _scene_units_geometry_node(only(children(reloaded))),
        )
        @test collect(after) ≈ collect(before)
    end
end
