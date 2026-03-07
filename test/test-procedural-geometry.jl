@testset "procedural geometry sources" begin
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    static_node = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
    procedural_node = Node(mtg, NodeMTG(:/, :Internode, 2, 2))

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

struct ParabolicLift
    factor::Float64
end

@inline function (lift::ParabolicLift)(p)
    SVector{3,Float64}(Float64(p[1]), Float64(p[2]), Float64(p[3]) + lift.factor * Float64(p[1])^2)
end

@testset "geometry transform replacement stays concrete" begin
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    node = Node(mtg, NodeMTG(:/, :Leaf, 1, 2))
    ref = RefMesh(
        "Triangle",
        GeometryBasics.Mesh(
            [Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), Point(0.0, 1.0, 0.0)],
            [GeometryBasics.TriangleFace(1, 2, 3)],
        ),
    )

    node[:geometry] = PlantGeom.Geometry(ref_mesh=ref, transformation=PlantGeom.Translation(1.0, 0.0, 0.0))
    @test typeof(node[:geometry]).parameters[2] === typeof(PlantGeom.Translation(1.0, 0.0, 0.0))

    PlantGeom.transform_mesh!(node, PlantGeom.LinearMap(Diagonal(SVector(2.0, 1.0, 1.0))))
    @test typeof(node[:geometry]).parameters[2] <: PlantGeom.Transformation

    mesh = PlantGeom.geometry_to_mesh(node[:geometry])
    pts = collect(GeometryBasics.coordinates(mesh))
    @test pts[1] ≈ Point(2.0, 0.0, 0.0)
    @test pts[2] ≈ Point(4.0, 0.0, 0.0)
    @test pts[3] ≈ Point(2.0, 1.0, 0.0)
end

@testset "point mapped geometry source" begin
    ref = RefMesh(
        "DeformedLeaf",
        GeometryBasics.Mesh(
            [Point(0.0, 0.0, 0.0), Point(0.5, 0.0, 0.0), Point(1.0, 0.0, 0.0)],
            [GeometryBasics.TriangleFace(1, 2, 3)],
        ),
        RGB(0.3, 0.7, 0.4),
    )
    geom = PointMappedGeometry(
        ref,
        ParabolicLift(0.25);
        transformation=PlantGeom.Translation(0.0, 1.0, 0.0),
    )

    mesh = PlantGeom.geometry_to_mesh(geom)
    pts = collect(GeometryBasics.coordinates(mesh))
    @test pts[1] ≈ Point(0.0, 1.0, 0.0)
    @test pts[2] ≈ Point(0.5, 1.0, 0.0625)
    @test pts[3] ≈ Point(1.0, 1.0, 0.25)
    @test PlantGeom.get_ref_mesh_name(geom) == "DeformedLeaf"
    @test PlantGeom.geometry_display_color(geom) == RGB(0.3, 0.7, 0.4)
end

@testset "rational bezier cereal leaf helpers" begin
    curve = PlantGeom.lamina_midrib(base_angle_deg=30.0, bend=0.25, tip_drop=0.08)
    @test curve(0.0) ≈ SVector{3,Float64}(0.0, 0.0, 0.0)
    @test isapprox(curve(1.0)[1], 1.0; atol=1e-8)
    @test curve(0.5)[3] > 0.0

    mesh = PlantGeom.lamina_mesh(1.1, 0.18; n_long=4, n_half=2)
    @test PlantGeom.nvertices(mesh) == 25
    @test PlantGeom.nelements(mesh) == 32
    xs = [p[1] for p in GeometryBasics.coordinates(mesh)]
    ys = [p[2] for p in GeometryBasics.coordinates(mesh)]
    @test minimum(xs) ≈ 0.0
    @test maximum(xs) ≈ 1.1
    @test maximum(abs, ys) > 0.05

    ref = PlantGeom.lamina_refmesh("CerealLeaf"; length=1.1, max_width=0.18, n_long=6, n_half=2)
    @test ref isa RefMesh
    @test ref.name == "CerealLeaf"
end

@testset "cereal leaf point mapping responds to base angle and bend" begin
    mild_map = PlantGeom.LaminaMidribMap(base_angle_deg=20.0, bend=0.20, tip_drop=0.04)
    steep_map = PlantGeom.LaminaMidribMap(base_angle_deg=48.0, bend=0.70, tip_drop=0.22)

    base_tangent_mild = mild_map.curve(0.02) - mild_map.curve(0.0)
    base_tangent_steep = steep_map.curve(0.02) - steep_map.curve(0.0)
    mild_angle = atan(base_tangent_mild[3], base_tangent_mild[1])
    steep_angle = atan(base_tangent_steep[3], base_tangent_steep[1])
    @test steep_angle > mild_angle + deg2rad(10.0)

    mild_tip = mild_map(Point(1.0, 0.0, 0.0))
    steep_tip = steep_map(Point(1.0, 0.0, 0.0))
    mild_mid = mild_map(Point(0.55, 0.0, 0.0))
    steep_mid = steep_map(Point(0.55, 0.0, 0.0))
    @test steep_tip[3] < mild_tip[3]
    @test steep_mid[3] > mild_mid[3]

    ref = PlantGeom.lamina_refmesh("Blade"; length=1.0, max_width=0.12, n_long=10, n_half=2)
    geom = PointMappedGeometry(ref, steep_map; transformation=PlantGeom.Translation(0.0, 0.5, 0.0))
    mesh = PlantGeom.geometry_to_mesh(geom)
    pts = collect(GeometryBasics.coordinates(mesh))
    @test minimum(p[2] for p in pts) > 0.3
    @test maximum(p[3] for p in pts) > 0.1

    extreme_bend = PlantGeom.LaminaMidribMap(base_angle_deg=35.0, bend=1.0, tip_drop=0.12)
    p_tip_extreme = extreme_bend(Point(1.0, 0.0, 0.0))
    @test p_tip_extreme[3] < -0.25

    p_before_tip = extreme_bend(Point(0.95, 0.0, 0.0))
    tip_dir = p_tip_extreme - p_before_tip
    tip_angle = atan(tip_dir[3], tip_dir[1])
    @test tip_angle < deg2rad(-60.0)
end

@testset "lamina twist roll map and composition" begin
    twist_only = PlantGeom.LaminaTwistRollMap(tip_twist_deg=90.0, roll_strength=0.0)
    p_tip = twist_only(Point(1.0, 0.1, 0.0))
    @test abs(p_tip[2]) < 1e-6
    @test p_tip[3] > 0.09

    roll_only = PlantGeom.LaminaTwistRollMap(tip_twist_deg=0.0, roll_strength=0.8, roll_exponent=1.0)
    p_roll = roll_only(Point(1.0, 0.1, 0.0))
    @test p_roll[3] > 0.007

    anticlastic_wave = PlantGeom.LaminaAnticlasticWaveMap(
        amplitude=0.02,
        wavelength=0.40,
        edge_exponent=1.0,
        progression_exponent=1.0,
        base_damping=0.0,
    )
    p_wave_center = anticlastic_wave(Point(0.5, 0.0, 0.0))
    p_wave_pos = anticlastic_wave(Point(0.5, 0.5, 0.0))
    p_wave_neg = anticlastic_wave(Point(0.5, -0.5, 0.0))
    @test abs(p_wave_center[3]) < 1e-10
    @test p_wave_pos[3] > 0.009
    @test p_wave_neg[3] < -0.009

    outline_wave = PlantGeom.LaminaAnticlasticWaveMap(
        amplitude=0.02,
        wavelength=0.40,
        edge_exponent=1.0,
        progression_exponent=1.0,
        base_damping=0.0,
        lateral_strength=1.0,
        vertical_strength=0.0,
    )
    p_outline_pos = outline_wave(Point(0.5, 0.5, 0.0))
    p_outline_neg = outline_wave(Point(0.5, -0.5, 0.0))
    @test p_outline_pos[2] > 0.509
    @test p_outline_neg[2] < -0.509

    damped_wave = PlantGeom.LaminaAnticlasticWaveMap(
        amplitude=0.03,
        wavelength=0.20,
        edge_exponent=1.0,
        progression_exponent=1.0,
        base_damping=8.0,
    )
    p_undamped_near_base = PlantGeom.LaminaAnticlasticWaveMap(
        amplitude=0.03,
        wavelength=0.20,
        edge_exponent=1.0,
        progression_exponent=1.0,
        base_damping=0.0,
    )(Point(0.05, 0.5, 0.0))
    p_damped_near_base = damped_wave(Point(0.05, 0.5, 0.0))
    @test p_undamped_near_base[3] > p_damped_near_base[3]

    asym_wave = PlantGeom.LaminaAnticlasticWaveMap(
        amplitude=0.02,
        wavelength=0.40,
        edge_exponent=1.0,
        progression_exponent=1.0,
        base_damping=0.0,
        asymmetry=0.5,
    )
    p_pos = asym_wave(Point(0.5, 0.5, 0.0))
    p_neg = asym_wave(Point(0.5, -0.5, 0.0))
    @test abs(p_pos[3]) > abs(p_neg[3]) + 0.008

    composed = PlantGeom.compose_point_maps(
        PlantGeom.LaminaAnticlasticWaveMap(amplitude=0.08, wavelength=0.20),
        PlantGeom.LaminaTwistRollMap(tip_twist_deg=30.0, roll_strength=0.6),
        PlantGeom.LaminaMidribMap(base_angle_deg=30.0, bend=0.45, tip_drop=0.12),
    )
    ref = PlantGeom.lamina_refmesh("BladeCompose"; length=1.0, max_width=1.0, n_long=8, n_half=2)
    geom = PointMappedGeometry(ref, composed)
    mesh = PlantGeom.geometry_to_mesh(geom)
    @test PlantGeom.nelements(mesh) > 0
    @test maximum(p[3] for p in GeometryBasics.coordinates(mesh)) > 0.1
end

@testset "point map frame applies dimensions before deformation" begin
    normalized_map = PlantGeom.LaminaMidribMap(base_angle_deg=22.0, bend=1.0, tip_drop=1.0)
    framed_map = PlantGeom.with_point_map_frame(normalized_map; length=1.0, width=0.12, z_scale=1.0)

    p_norm = normalized_map(Point(1.0, 0.0, 0.0))
    p_frame = framed_map(Point(1.0, 0.0, 0.0))
    @test p_frame[3] ≈ p_norm[3] atol=1e-8

    p_margin = framed_map(Point(0.5, 0.5, 0.0))
    @test p_margin[2] > 0.01
    @test p_margin[2] < 0.08

    composed = PlantGeom.compose_point_maps(
        PlantGeom.LaminaTwistRollMap(tip_twist_deg=6.0, roll_strength=0.2),
        normalized_map,
    )
    framed_composed = PlantGeom.with_point_map_frame(composed; length=1.0, width=0.12, z_scale=1.0)
    p_composed = framed_composed(Point(0.5, 0.5, 0.0))
    @test isfinite(p_composed[1]) && isfinite(p_composed[2]) && isfinite(p_composed[3])

    # Framed maps should behave consistently even if the reference mesh uses
    # different source dimensions.
    ref_unit = PlantGeom.lamina_refmesh("BladeUnit"; length=1.0, max_width=1.0, n_long=16, n_half=3)
    ref_scaled = PlantGeom.lamina_refmesh("BladeScaled"; length=8.0, max_width=2.4, n_long=16, n_half=3)
    framed_geometry_map = PlantGeom.with_point_map_frame(
        PlantGeom.compose_point_maps(
            PlantGeom.LaminaTwistRollMap(tip_twist_deg=3.0, roll_strength=0.05),
            PlantGeom.LaminaMidribMap(base_angle_deg=46.0, bend=0.02, tip_drop=0.0),
        );
        length=1.0,
        width=0.12,
        z_scale=1.0,
    )
    geom_unit = PointMappedGeometry(ref_unit, framed_geometry_map)
    geom_scaled = PointMappedGeometry(ref_scaled, framed_geometry_map)
    pts_unit = collect(GeometryBasics.coordinates(PlantGeom.geometry_to_mesh(geom_unit)))
    pts_scaled = collect(GeometryBasics.coordinates(PlantGeom.geometry_to_mesh(geom_scaled)))
    @test length(pts_unit) == length(pts_scaled)
    @test all(isapprox(pts_unit[i], pts_scaled[i]; atol=1e-8, rtol=1e-8) for i in eachindex(pts_unit))
end

@testset "biomechanical bending transformation" begin
    initial = deg2rad(28.0)
    flexible_final = PlantGeom.final_angle(25.0, initial, 0.6, 0.55)
    stiff_final = PlantGeom.final_angle(1e12, initial, 0.6, 0.55)
    @test flexible_final > initial
    @test abs(stiff_final - initial) < deg2rad(0.35)

    segments = collect(range(0.0, 1.0; length=18))
    profile = PlantGeom.calculate_segment_angles(25.0, initial, 0.6, 0.55, segments)
    @test length(profile) == length(segments)
    @test issorted(profile)
    @test profile[end] > profile[1]

    bend_flexible = PlantGeom.BiomechanicalBendingTransform(
        25.0,
        initial,
        1.0,
        0.55;
        x_min=0.0,
        x_max=1.0,
        n_samples=128,
    )
    bend_stiff = PlantGeom.BiomechanicalBendingTransform(
        1e12,
        initial,
        1.0,
        0.55;
        x_min=0.0,
        x_max=1.0,
        n_samples=128,
    )
    tip_flexible = bend_flexible(SVector{3,Float64}(1.0, 0.0, 0.0))
    tip_stiff = bend_stiff(SVector{3,Float64}(1.0, 0.0, 0.0))
    @test tip_flexible[3] < tip_stiff[3]

    node = Node(Node(NodeMTG(:/, :Plant, 1, 1)), NodeMTG(:/, :Leaf, 1, 2))
    node[:geometry] = PlantGeom.Geometry(
        ref_mesh=PlantGeom.lamina_refmesh("BendingLeaf"; n_long=6, n_half=2, max_width=0.08),
        transformation=PlantGeom.IdentityTransformation(),
    )
    PlantGeom.transform_mesh!(node, bend_flexible)
    bent_mesh = PlantGeom.geometry_to_mesh(node[:geometry])
    points = collect(GeometryBasics.coordinates(bent_mesh))
    @test minimum(p[3] for p in points) < -0.15
end

@testset "biomechanical segment-chain bending" begin
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    leaflet = Node(mtg, NodeMTG(:+, :Leaflet, 1, 2))
    segment_positions = [0.0, 0.18, 0.42, 0.68, 0.90]

    for (i, pos) in enumerate(segment_positions)
        seg = Node(leaflet, NodeMTG(:/, :LeafletSegment, i, 3))
        seg[:segment_boundaries] = pos
    end

    boundary_angles = PlantGeom.update_segment_angles!(
        leaflet,
        25.0,
        deg2rad(28.0),
        1.0,
        0.55;
        segment_symbol=:LeafletSegment,
        position_key=:segment_boundaries,
        angle_key=:zenithal_angle,
        degrees=true,
    )
    @test length(boundary_angles) == length(segment_positions)
    @test issorted(boundary_angles)

    segment_nodes = collect(descendants(leaflet, symbol=:LeafletSegment))
    stored_deg = [node[:zenithal_angle] for node in segment_nodes]
    @test issorted(stored_deg)
    @test isapprox(deg2rad(stored_deg[end]), boundary_angles[end]; atol=1e-8)

    boundary_again = PlantGeom.update_segment_angles!(
        segment_nodes,
        25.0,
        deg2rad(28.0),
        1.0,
        0.55;
        segment_positions=segment_positions,
        mode=:incremental,
        angle_key=:local_flexion_angle,
        degrees=false,
    )
    local_values = [node[:local_flexion_angle] for node in segment_nodes]
    @test isapprox(local_values[1], boundary_again[1]; atol=1e-10)
    @test isapprox(sum(local_values[2:end]), boundary_again[end] - boundary_again[1]; atol=1e-8)
end
