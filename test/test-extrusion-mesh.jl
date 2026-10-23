@testset "Extrusion Mesh" begin
    section_open = [
        Point(-1.0, 0.0, 0.0),
        Point(1.0, 0.0, 0.0),
    ]
    path = [
        Point(0.0, 0.0, 0.0),
        Point(1.0, 0.0, 0.0),
    ]

    mesh_open = extrude_profile_mesh(
        section_open,
        path;
        widths=[1.0, 2.0],
        heights=[1.0, 1.0],
        path_normals=[(0.0, 0.0, 1.0), (0.0, 0.0, 1.0)],
        close_section=false,
    )

    @test nvertices(mesh_open) == 4
    @test nelements(mesh_open) == 2

    coords_open = GeometryBasics.coordinates(mesh_open)
    d_start = norm(coords_open[2] - coords_open[1])
    d_end = norm(coords_open[4] - coords_open[3])
    @test isapprox(d_end / d_start, 2.0; atol=1e-8)

    section_closed = [
        Point(-1.0, -1.0, 0.0),
        Point(1.0, -1.0, 0.0),
        Point(1.0, 1.0, 0.0),
        Point(-1.0, 1.0, 0.0),
    ]

    mesh_closed = extrude_profile_mesh(
        section_closed,
        path;
        close_section=true,
        cap_ends=true,
    )

    @test nvertices(mesh_closed) == 10 # 2 rings * 4 + 2 cap centers
    @test nelements(mesh_closed) == 16 # sides: 8, caps: 8

    ref = extrude_profile_refmesh("leaflet", section_open, path; close_section=false)
    @test ref isa RefMesh
    @test ref.name == "leaflet"
    @test nvertices(ref) == 4
    @test nelements(ref) == 2

    prof = leaflet_midrib_profile(; lamina_angle_deg=60.0, scale=0.5)
    @test length(prof) == 3
    @test isapprox(prof[1][1], -prof[3][1]; atol=1e-10)
    @test isapprox(prof[1][2], prof[3][2]; atol=1e-10)
    @test isapprox(prof[2][1], 0.0; atol=1e-10)
    @test isapprox(prof[2][2], 0.0; atol=1e-10)

    circ = circle_section_profile(6; radius=0.5, close_loop=true)
    @test length(circ) == 7
    @test norm(circ[1] - circ[end]) < 1e-12

    tube_mesh = extrude_tube_mesh(path; n_sides=6, radius=0.5, cap_ends=false)
    @test nvertices(tube_mesh) == 12 # 2 rings * 6
    @test nelements(tube_mesh) == 12 # 6 quads -> 12 triangles

    tube_caps = extrude_tube_mesh(path; n_sides=6, radius=0.5, cap_ends=true)
    @test nvertices(tube_caps) == 14 # +2 cap centers
    @test nelements(tube_caps) == 24 # sides 12 + caps 12

    tube_ref = RefMesh("tube", extrude_tube_mesh(path; n_sides=6, radius=0.5))
    @test tube_ref isa RefMesh
    @test tube_ref.name == "tube"
    @test nvertices(tube_ref) == 12
    @test nelements(tube_ref) == 12

    path_key = [
        Point(0.0, 0.0, 0.0),
        Point(0.5, 0.2, 0.0),
        Point(1.0, 0.0, 0.0),
    ]
    path_spline = extrusion_make_spline(12, path_key)
    path_hermite = extrusion_make_path(12, path_key)
    @test length(path_spline) == 13
    @test length(path_hermite) == 13
    @test norm(path_spline[1] - path_key[1]) < 1e-8
    @test norm(path_spline[end] - path_key[end]) < 1e-8
    @test norm(path_hermite[1] - path_key[1]) < 1e-8
    @test norm(path_hermite[end] - path_key[end]) < 1e-8

    interp = extrusion_make_interpolation(10, [1.0, 2.0, 4.0])
    @test length(interp) == 11
    @test isapprox(interp[1], 1.0; atol=1e-8)
    @test isapprox(interp[end], 4.0; atol=1e-8)

    z_curve, r_curve = extrusion_make_curve([0.0, 1.0, 2.0], [0.2, 1.0, 0.3], 20)
    @test length(z_curve) == 21
    @test length(r_curve) == 21
    @test isapprox(z_curve[1], 0.0; atol=1e-8)
    @test isapprox(z_curve[end], 2.0; atol=1e-8)
    @test isapprox(r_curve[1], 0.2; atol=1e-8)
    @test isapprox(r_curve[end], 0.3; atol=1e-8)
    @test maximum(r_curve) <= 1.05

    z_keys = [0.0, 0.3, 0.8, 1.0]
    r_keys = [0.2, 0.4, 0.3, 0.1]
    lathe_m = lathe_mesh(10, 20, z_keys, r_keys; method=:curve, axis=:x, cap_ends=true)
    @test nvertices(lathe_m) > 0
    @test nelements(lathe_m) > 0

    lathe_ref = lathe_refmesh("lathe", 10, 20, z_keys, r_keys; method=:curve, axis=:x, cap_ends=true)
    @test lathe_ref isa RefMesh
    @test nvertices(lathe_ref) == nvertices(lathe_m)
    @test nelements(lathe_ref) == nelements(lathe_m)

    cache = Dict{Any,Any}()
    tube_key_1 = (:tube, "tube_cached", 8, 0.4, RGB(220 / 255, 220 / 255, 220 / 255))
    tube_key_2 = (:tube, "tube_cached", 8, 0.5, RGB(220 / 255, 220 / 255, 220 / 255))
    tube_key_3 = (:tube, "tube_cached", 8, 0.4, RGB(0.1, 0.2, 0.3))
    tube_c1 = get!(cache, tube_key_1) do
        RefMesh("tube_cached", extrude_tube_mesh(path; n_sides=8, radius=0.4))
    end
    tube_c2 = get!(cache, tube_key_1) do
        RefMesh("tube_cached", extrude_tube_mesh(path; n_sides=8, radius=0.4))
    end
    tube_c3 = get!(cache, tube_key_2) do
        RefMesh("tube_cached", extrude_tube_mesh(path; n_sides=8, radius=0.5))
    end
    tube_c4 = get!(cache, tube_key_3) do
        RefMesh("tube_cached", extrude_tube_mesh(path; n_sides=8, radius=0.4), RGB(0.1, 0.2, 0.3))
    end
    @test tube_c1 === tube_c2
    @test tube_c1 !== tube_c3
    @test tube_c1 !== tube_c4

    lathe_c1 = lathe_refmesh("lathe_cached", 8, 16, z_keys, r_keys; cache=cache, method=:curve)
    lathe_c2 = lathe_refmesh("lathe_cached", 8, 16, z_keys, r_keys; cache=cache, method=:curve)
    lathe_c3 = lathe_refmesh("lathe_cached", 8, 16, z_keys, [0.2, 0.45, 0.3, 0.1]; cache=cache, method=:curve)
    @test lathe_c1 === lathe_c2
    @test lathe_c1 !== lathe_c3

    lathe_g1 = lathe_gen_refmesh("lathe_gen_cached", 8, [0.0, 1.0], [0.2, 0.1]; cache=cache)
    lathe_g2 = lathe_gen_refmesh("lathe_gen_cached", 8, [0.0, 1.0], [0.2, 0.1]; cache=cache)
    lathe_g3 = lathe_gen_refmesh("lathe_gen_cached", 8, [0.0, 1.0], [0.2, 0.15]; cache=cache)
    @test lathe_g1 === lathe_g2
    @test lathe_g1 !== lathe_g3
end

@testset "Extrusion closed-section winding" begin
    # These checks use geometric triangle normals and an independent polygonal
    # frustum volume, not shading normals or the generator's index order.
    function winding_metrics(mesh, base, tip)
        points = [Float64.(collect(point)) for point in GeometryBasics.coordinates(mesh)]
        faces = [Tuple(Int.(collect(face))) for face in GeometryBasics.faces(mesh)]
        base, tip = Float64.(base), Float64.(tip)
        main = (tip - base) / norm(tip - base)
        height = norm(tip - base)
        origin = reduce(+, points) / length(points)
        side_outward = caps_outward = true
        area = signed_volume = 0.0
        degenerate = 0
        edges = Dict{Tuple{Int,Int},Vector{Int}}()
        for face in faces
            a, b, c = points[collect(face)]
            twice_normal = cross(b - a, c - a)
            twice_area = norm(twice_normal)
            area += twice_area / 2
            signed_volume += dot(a - origin, cross(b - origin, c - origin)) / 6
            for (u, v) in ((face[1], face[2]), (face[2], face[3]), (face[3], face[1]))
                push!(get!(edges, minmax(u, v), Int[]), u < v ? 1 : -1)
            end
            if twice_area <= 1.0e-12
                degenerate += 1
                continue
            end
            normal = twice_normal / twice_area
            axial = [dot(point - base, main) for point in (a, b, c)]
            if all(abs(value) <= 1.0e-11 for value in axial)
                caps_outward &= dot(normal, -main) > 1 - 1.0e-11
            elseif all(abs(value - height) <= 1.0e-11 for value in axial)
                caps_outward &= dot(normal, main) > 1 - 1.0e-11
            else
                centroid = (a + b + c) / 3
                radial = centroid - base - dot(centroid - base, main) * main
                side_outward &= dot(normal, radial) > 1.0e-11
            end
        end
        return (; points, faces, area, signed_volume, side_outward, caps_outward,
            degenerate,
            boundary_edges=count(value -> length(value) == 1, values(edges)),
            nonmanifold_edges=count(value -> length(value) > 2, values(edges)),
            orientation_conflicts=count(value -> length(value) == 2 && sum(value) != 0,
                values(edges)))
    end

    rectangle = [Point(-1.0, -0.5, 0.0), Point(1.0, -0.5, 0.0),
        Point(1.0, 0.5, 0.0), Point(-1.0, 0.5, 0.0)]
    circle = circle_section_profile(8; radius=0.5, close_loop=false)
    profiles = ((rectangle, 2.0), (circle, 8 * 0.5^2 * sin(2pi / 8) / 2))
    directions = ([1.0, 0.0, 0.0], [-1.0, 0.0, 0.0], [2.0, -3.0, 6.0] / 7)
    scales = ((1.6, 0.7), (-1.6, 0.7), (1.6, -0.7), (-1.6, -0.7))
    base = [1.25, -2.5, 0.75]
    path_length = 3.0
    start_scale, end_scale = 1.25, 0.5
    for (profile, section_area) in profiles, reversed in (false, true),
        direction in directions, (width, height) in scales
        section = reversed ? reverse(profile) : profile
        tip = base + path_length * direction
        path = [Point(base...), Point(tip...)]
        mesh = extrude_profile_mesh(section, path;
            widths=[start_scale * width, end_scale * width],
            heights=[start_scale * height, end_scale * height],
            close_section=true, cap_ends=true)
        observed = winding_metrics(mesh, base, tip)
        expected_volume = section_area * abs(width * height) * path_length / 3 *
            (start_scale^2 + start_scale * end_scale + end_scale^2)
        @test all(all(isfinite, point) for point in observed.points)
        @test observed.degenerate == 0
        @test observed.side_outward
        @test observed.caps_outward
        @test observed.signed_volume > 0
        @test observed.signed_volume ≈ expected_volume atol=1.0e-11 rtol=1.0e-11
        @test observed.boundary_edges == 0
        @test observed.nonmanifold_edges == 0
        @test observed.orientation_conflicts == 0
        @test observed.area > 0
    end

    # An explicit repeated endpoint is removed before assessing section order.
    path = [Point(0.0, 0.0, 0.0), Point(3.0, 0.0, 0.0)]
    for (profile, _) in profiles, reversed in (false, true)
        section = reversed ? reverse(profile) : profile
        plain = extrude_profile_mesh(section, path; close_section=true, cap_ends=true)
        repeated = extrude_profile_mesh(vcat(section, [first(section)]), path;
            cap_ends=true)
        @test collect(GeometryBasics.coordinates(repeated)) ==
            collect(GeometryBasics.coordinates(plain))
        @test collect(GeometryBasics.faces(repeated)) == collect(GeometryBasics.faces(plain))
    end

    # A zero initial ring must not hide the reflection of the later nonzero ring.
    for (width, height) in ((1.0, 1.0), (-1.0, 1.0), (-1.0, -1.0))
        cone = extrude_profile_mesh(circle, path; widths=[0.0, width],
            heights=[0.0, height], close_section=true, cap_ends=true)
        observed = winding_metrics(cone, [0.0, 0.0, 0.0], [3.0, 0.0, 0.0])
        expected_volume = profiles[2][2] * 3.0 / 3
        @test all(all(isfinite, point) for point in observed.points)
        @test observed.degenerate > 0
        @test observed.side_outward
        @test observed.caps_outward
        @test observed.signed_volume ≈ expected_volume atol=1.0e-11
    end

    # An open ribbon has no solid interior. Retain its historical face order;
    # reversing the authored profile is the caller's choice of surface side.
    open_profile = [Point(-1.0, 0.0, 0.0), Point(0.0, 0.4, 0.0), Point(1.0, 0.0, 0.0)]
    ribbons = [extrude_profile_mesh(section, path; close_section=false)
        for section in (open_profile, reverse(open_profile))]
    oriented_areas = Vector{Float64}[]
    for ribbon in ribbons
        points = collect(GeometryBasics.coordinates(ribbon))
        faces = collect(GeometryBasics.faces(ribbon))
        @test Tuple.(faces) == [(1, 2, 5), (1, 5, 4), (2, 3, 6), (2, 6, 5)]
        oriented = zeros(3)
        area = 0.0
        for face in faces
            a, b, c = points[Int.(collect(face))]
            normal = cross(b - a, c - a)
            oriented += normal / 2
            area += norm(normal) / 2
        end
        @test area ≈ 6 * hypot(1.0, 0.4) atol=1.0e-11
        push!(oriented_areas, oriented)
    end
    @test oriented_areas[1] ≈ -oriented_areas[2] atol=1.0e-11
end
