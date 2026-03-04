@testset "procedural geometry visual regression" begin
    section = leaflet_midrib_profile(; lamina_angle_deg=58.0, scale=0.22)
    path = extrusion_make_spline(
        24,
        [
            Point(0.0, 0.0, 0.0),
            Point(0.25, 0.04, 0.03),
            Point(0.58, 0.12, 0.09),
            Point(0.95, 0.10, 0.02),
        ],
    )
    widths = collect(range(1.2, 0.55; length=length(path)))
    heights = collect(range(0.8, 0.35; length=length(path)))
    extrusion_ref = extrude_profile_refmesh(
        "ExtrusionLeaf",
        section,
        path;
        widths=widths,
        heights=heights,
        close_section=false,
        torsion=false,
        material=RGB(0.20, 0.58, 0.32),
    )
    @test_reference "reference_images/procedural_extrusion.png" plantviz([extrusion_ref])

    z_keys = [0.0, 0.2, 0.5, 0.9, 1.2]
    r_keys = [0.0, 0.09, 0.16, 0.08, 0.03]
    lathe_ref = lathe_refmesh(
        "LatheFruit",
        28,
        64,
        z_keys,
        r_keys;
        method=:curve,
        axis=:x,
        cap_ends=true,
        material=RGB(0.85, 0.62, 0.28),
    )
    @test_reference "reference_images/procedural_lathe.png" plantviz([lathe_ref])

    cereal = Node(NodeMTG(:/, :Plant, 1, 1))
    stem = Node(cereal, NodeMTG(:/, :Stem, 1, 2))
    stem_path = [
        Point(0.0, 0.0, 0.0),
        Point(0.0, 0.0, 0.44),
        Point(0.0, 0.0, 0.92),
        Point(0.0, 0.0, 1.26),
    ]
    stem[:geometry] = ExtrudedTubeGeometry(
        stem_path;
        n_sides=14,
        radius=0.022,
        radii=[1.0, 0.90, 0.74, 0.50],
        torsion=false,
        cap_ends=true,
        material=RGB(0.54, 0.76, 0.38),
    )

    blade_ref = cereal_leaf_refmesh(
        "CerealBlade";
        length=1.0,
        max_width=0.12,
        n_long=40,
        n_half=8,
        material=RGB(0.20, 0.60, 0.22),
    )

    leaf_specs = [
        (
            z=0.20,
            azimuth_deg=-35.0,
            base_angle_deg=18.0,
            bend=0.18,
            tip_drop=0.05,
            twist=8.0,
            roll=0.18,
            wave_amp=0.008,
            wave_len=0.18,
            scale=0.82,
        ),
        (
            z=0.56,
            azimuth_deg=84.0,
            base_angle_deg=30.0,
            bend=0.40,
            tip_drop=0.11,
            twist=18.0,
            roll=0.30,
            wave_amp=0.010,
            wave_len=0.15,
            scale=0.96,
        ),
        (
            z=0.90,
            azimuth_deg=208.0,
            base_angle_deg=44.0,
            bend=0.74,
            tip_drop=0.24,
            twist=34.0,
            roll=0.44,
            wave_amp=0.012,
            wave_len=0.12,
            scale=1.05,
        ),
    ]

    for (i, spec) in enumerate(leaf_specs)
        leaf = Node(stem, NodeMTG(:+, :Leaf, i, 2))
        point_map = compose_point_maps(
            LaminaMarginWaveMap(
                length=1.0,
                max_half_width=0.06,
                amplitude=spec.wave_amp,
                wavelength=spec.wave_len,
                edge_exponent=1.6,
                progression_exponent=1.1,
                base_damping=5.0,
                phase_deg=25.0 * i,
                asymmetry=0.10,
                lateral_strength=0.0,
                vertical_strength=1.0,
            ),
            LaminaTwistRollMap(
                length=1.0,
                tip_twist_deg=spec.twist,
                roll_strength=spec.roll,
                roll_exponent=1.2,
            ),
            CerealLeafMap(length=1.0, base_angle_deg=spec.base_angle_deg, bend=spec.bend, tip_drop=spec.tip_drop),
        )
        leaf[:geometry] = PointMappedGeometry(
            blade_ref,
            point_map;
            transformation=PlantGeom.compose(
                PlantGeom.Translation(0.0, 0.0, spec.z),
                PlantGeom.LinearMap(PlantGeom.RotZ(deg2rad(spec.azimuth_deg))),
                PlantGeom.LinearMap(Diagonal(SVector(spec.scale, spec.scale, spec.scale))),
            ),
        )
    end

    terminal_leaf = Node(stem, NodeMTG(:+, :Leaf, length(leaf_specs) + 1, 2))
    stem_top_z = stem_path[end][3]
    terminal_leaf[:geometry] = PointMappedGeometry(
        blade_ref,
        compose_point_maps(
            LaminaMarginWaveMap(
                length=1.0,
                max_half_width=0.06,
                amplitude=0.008,
                wavelength=0.16,
                edge_exponent=1.6,
                progression_exponent=1.1,
                base_damping=5.0,
                phase_deg=10.0,
                asymmetry=0.05,
                lateral_strength=0.0,
                vertical_strength=1.0,
            ),
            LaminaTwistRollMap(
                length=1.0,
                tip_twist_deg=10.0,
                roll_strength=0.20,
                roll_exponent=1.1,
            ),
            CerealLeafMap(
                length=1.0,
                base_angle_deg=72.0,
                bend=0.28,
                tip_drop=0.06,
            ),
        );
        transformation=PlantGeom.compose(
            PlantGeom.Translation(0.0, 0.0, stem_top_z),
            PlantGeom.LinearMap(PlantGeom.RotZ(deg2rad(6.0))),
            PlantGeom.LinearMap(Diagonal(SVector(0.76, 0.76, 0.76))),
        ),
    )

    @test_reference "reference_images/procedural_cereal_pointmapped.png" plantviz(
        cereal,
        color=Dict("CerealBlade" => RGB(0.20, 0.60, 0.22), "ExtrudedTube" => RGB(0.54, 0.76, 0.38)),
    )

    compare_ref = cereal_leaf_refmesh(
        "CerealBladeCompare";
        length=1.0,
        max_width=0.14,
        n_long=72,
        n_half=14,
        material=RGB(0.20, 0.60, 0.22),
    )
    smooth_leaf = PointMappedGeometry(
        compare_ref,
        compose_point_maps(
            LaminaTwistRollMap(length=1.0, tip_twist_deg=20.0, roll_strength=0.32, roll_exponent=1.15),
            CerealLeafMap(length=1.0, base_angle_deg=34.0, bend=0.56, tip_drop=0.16),
        );
        transformation=PlantGeom.Translation(0.0, -0.20, 0.0),
    )
    wavy_leaf = PointMappedGeometry(
        compare_ref,
        compose_point_maps(
            LaminaMarginWaveMap(
                length=1.0,
                max_half_width=0.07,
                amplitude=0.022,
                wavelength=0.115,
                edge_exponent=1.7,
                progression_exponent=1.1,
                base_damping=4.5,
                phase_deg=18.0,
                lateral_strength=0.0,
                vertical_strength=1.0,
            ),
            LaminaTwistRollMap(length=1.0, tip_twist_deg=20.0, roll_strength=0.32, roll_exponent=1.15),
            CerealLeafMap(length=1.0, base_angle_deg=34.0, bend=0.56, tip_drop=0.16),
        );
        transformation=PlantGeom.Translation(0.0, 0.20, 0.0),
    )

    fig = Figure(size=(1200, 520))
    ax = Axis3(
        fig[1, 1];
        title="Cereal leaf margin wave (top: wavy, bottom: smooth)",
        azimuth=1.45,
        elevation=0.36,
        perspectiveness=0.7,
    )
    mesh!(ax, PlantGeom.geometry_to_mesh(smooth_leaf), color=RGBA(0.18, 0.58, 0.22, 0.95))
    mesh!(ax, PlantGeom.geometry_to_mesh(wavy_leaf), color=RGBA(0.14, 0.50, 0.18, 0.95))
    Makie.xlims!(ax, -0.03, 1.05)
    Makie.ylims!(ax, -0.33, 0.33)
    Makie.zlims!(ax, -0.26, 0.56)

    @test_reference "reference_images/procedural_cereal_margin_wave.png" fig
end
