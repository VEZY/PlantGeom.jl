@testset "manual transform helpers" begin
    @test PlantGeom.scale3(2.0)(SVector(1.0, 2.0, 3.0)) ≈ SVector(2.0, 4.0, 6.0)
    @test PlantGeom.scale3((2.0, 3.0, 4.0))(SVector(1.0, 1.0, 1.0)) ≈ SVector(2.0, 3.0, 4.0)

    @test PlantGeom.rotate_x(90.0; deg=true)(SVector(0.0, 1.0, 0.0)) ≈ SVector(0.0, 0.0, 1.0) atol = 1e-12
    @test PlantGeom.rotate_y(90.0; deg=true)(SVector(0.0, 0.0, 1.0)) ≈ SVector(1.0, 0.0, 0.0) atol = 1e-12
    @test PlantGeom.rotate_z(90.0; deg=true)(SVector(1.0, 0.0, 0.0)) ≈ SVector(0.0, 1.0, 0.0) atol = 1e-12

    @testset "pose applies scale then rotations then translation" begin
        t = PlantGeom.pose(
            scale=(2.0, 1.0, 1.0),
            rotate=(z=90.0,),
            at=(1.0, 0.0, 0.0),
            deg=true,
        )

        got = t(SVector(1.0, 0.0, 0.0))
        @test got ≈ SVector(1.0, 2.0, 0.0) atol = 1e-12
    end

    @testset "pose works directly in Geometry" begin
        ref = RefMesh(
            "Panel",
            GeometryBasics.Mesh(
                [Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), Point(0.0, 1.0, 0.0)],
                [GeometryBasics.TriangleFace(1, 2, 3)],
            ),
        )

        geom = PlantGeom.Geometry(
            ref_mesh=ref,
            transformation=PlantGeom.pose(
                scale=(2.0, 1.0, 0.1),
                rotate=(y=90.0,),
                at=(0.0, 0.0, 1.0),
                deg=true,
            ),
        )

        mesh = PlantGeom.geometry_to_mesh(geom)
        pts = collect(GeometryBasics.coordinates(mesh))

        @test pts[1] ≈ Point(0.0, 0.0, 1.0)
        @test pts[2] ≈ Point(0.0, 0.0, -1.0) atol = 1e-12
        @test pts[3] ≈ Point(0.0, 1.0, 1.0) atol = 1e-12
    end

    @testset "pose preserves named rotation order" begin
        xy = PlantGeom.pose(; rotate=(x=90.0, y=90.0), deg=true)
        yx = PlantGeom.pose(; rotate=(y=90.0, x=90.0), deg=true)
        point = SVector(1.0, 1.0, 1.0)

        @test !(xy(point) ≈ yx(point))
        @test PlantGeom.pose(; rotate=(90.0, 90.0, 0.0), deg=true)(point) ≈ xy(point) atol = 1e-12
    end
end
