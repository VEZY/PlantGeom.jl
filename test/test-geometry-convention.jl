@testset "geometry conventions" begin
    tri = GeometryBasics.Mesh(
        [
            GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0),
            GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0),
            GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0),
        ],
        [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
    )
    ref = RefMesh("tri", tri)

    @testset "default aliases" begin
        node = Dict{Symbol,Any}(
            :Length => 2.0,
            :Width => 0.5,
            :XEuler => 90.0,
            :xx => 1.0,
            :yy => 2.0,
            :zz => 3.0,
        )

        got = transformation_from_attributes(node)

        expected = PlantGeom.IdentityTransformation()
        expected = expected ∘ PlantGeom.LinearMap(Diagonal(SVector(0.5, 0.5, 2.0)))
        expected = expected ∘ PlantGeom.LinearMap(PlantGeom.RotMatrix(PlantGeom.AngleAxis(pi / 2, 1.0, 0.0, 0.0)))
        expected = PlantGeom.Translation(1.0, 2.0, 3.0) ∘ expected

        got_mat = PlantGeom.transformation_matrix4(got)
        expected_mat = PlantGeom.transformation_matrix4(expected)
        @test maximum(abs.(got_mat .- expected_mat)) < 1e-12
    end

    @testset "lowercase aliases" begin
        node = Dict{Symbol,Any}(
            :length => 3.0,
            :width => 2.0,
            :zeuler => 90.0,
            :xx => 1.0,
            :yy => -1.0,
            :zz => 0.5,
        )

        got = transformation_from_attributes(node)

        expected = PlantGeom.IdentityTransformation()
        expected = expected ∘ PlantGeom.LinearMap(Diagonal(SVector(2.0, 2.0, 3.0)))
        expected = expected ∘ PlantGeom.LinearMap(PlantGeom.RotMatrix(PlantGeom.AngleAxis(pi / 2, 0.0, 0.0, 1.0)))
        expected = PlantGeom.Translation(1.0, -1.0, 0.5) ∘ expected

        got_mat = PlantGeom.transformation_matrix4(got)
        expected_mat = PlantGeom.transformation_matrix4(expected)
        @test maximum(abs.(got_mat .- expected_mat)) < 1e-12
    end

    @testset "local vs global angle frames" begin
        node = Dict{Symbol,Any}(:XEuler => 90.0, :ZEuler => 90.0)

        local_conv = default_geometry_convention()
        global_conv = GeometryConvention(
            scale_map=local_conv.scale_map,
            angle_map=[
                (names=[:XEuler], axis=:x, frame=:local, unit=:deg, pivot=:origin),
                (names=[:ZEuler], axis=:z, frame=:global, unit=:deg, pivot=:origin),
            ],
            translation_map=local_conv.translation_map,
            length_axis=:z,
        )

        local_mat = PlantGeom.transformation_matrix4(transformation_from_attributes(node; convention=local_conv))
        global_mat = PlantGeom.transformation_matrix4(transformation_from_attributes(node; convention=global_conv))

        @test maximum(abs.(local_mat .- global_mat)) > 1e-6
    end

    @testset "global pivot support" begin
        node = Dict{Symbol,Any}(:theta => 90.0, :px => 1.0, :py => 0.0, :pz => 0.0)

        conv = GeometryConvention(
            scale_map=Dict(:length => Symbol[], :width => Symbol[], :thickness => Symbol[]),
            angle_map=[(names=[:theta], axis=:z, frame=:global, unit=:deg, pivot=(:px, :py, :pz))],
            translation_map=Dict(:x => Symbol[], :y => Symbol[], :z => Symbol[]),
            length_axis=:z,
        )

        t = transformation_from_attributes(node; convention=conv)
        p = SVector(2.0, 0.0, 0.0)
        got = t(p)
        @test collect(got) ≈ [1.0, 1.0, 0.0] atol = 1e-12
    end

    @testset "angle units" begin
        deg_t = transformation_from_attributes(Dict{Symbol,Any}(:ZEuler => 90.0))
        got_deg = deg_t(SVector(1.0, 0.0, 0.0))
        @test collect(got_deg) ≈ [0.0, 1.0, 0.0] atol = 1e-12

        rad_conv = default_geometry_convention(angle_unit=:rad)
        rad_t = transformation_from_attributes(Dict{Symbol,Any}(:ZEuler => pi / 2); convention=rad_conv)
        got_rad = rad_t(SVector(1.0, 0.0, 0.0))
        @test collect(got_rad) ≈ [0.0, 1.0, 0.0] atol = 1e-12
    end

    @testset "missing attributes are lenient" begin
        t = transformation_from_attributes(Dict{Symbol,Any}())
        @test PlantGeom.transformation_matrix4(t) ≈ Matrix{Float64}(I, 4, 4)
    end

    @testset "translation applied last" begin
        node = Dict{Symbol,Any}(:theta => 90.0, :tx => 1.0)
        conv = GeometryConvention(
            scale_map=Dict(:length => Symbol[], :width => Symbol[], :thickness => Symbol[]),
            angle_map=[(names=[:theta], axis=:z, frame=:global, unit=:deg, pivot=:origin)],
            translation_map=Dict(:x => [:tx], :y => Symbol[], :z => Symbol[]),
            length_axis=:z,
        )

        t = transformation_from_attributes(node; convention=conv)
        got = t(SVector(0.0, 0.0, 0.0))
        @test collect(got) ≈ [1.0, 0.0, 0.0] atol = 1e-12
    end

    @testset "geometry helpers" begin
        node = Dict{Symbol,Any}(:Length => 2.0)
        geom = geometry_from_attributes(node, ref)
        @test geom isa PlantGeom.Geometry
        @test geom.ref_mesh === ref

        set_geometry_from_attributes!(node, ref)
        @test haskey(node, :geometry)
        @test node[:geometry] isa PlantGeom.Geometry
    end
end
