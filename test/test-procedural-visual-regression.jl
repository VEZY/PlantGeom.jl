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
end
