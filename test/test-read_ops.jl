file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene.ops")
@testset "read_ops" begin
    ops = @test_nowarn read_ops(file)
    @test ops.scene_dimensions == (PlantGeom.Point3(0.0, 0.0, 0.0), PlantGeom.Point3(2.0, 1.0, 0.0))
    @test length(get_ref_meshes(ops)) == 5
    #Note: there are only 4 ref_meshes because the same opf file is used for the simple_plants,
    # so we can optimize it by only using the common ones.
    opfs = children(ops)
    length(opfs) == 6
    opfs[1].filePath == "coffee.opf"
    [@test(p.filePath == "simple_plant.opf") for p in opfs[2:end]]
    @test [p.plantID for p in opfs] == collect(1:6)
    @test [p.sceneID for p in opfs] == fill(1, 6)
    @test opfs[1].pos == PlantGeom.Point3(0.0, 0.0, 0.0)
    @test opfs[6].pos == PlantGeom.Point3(2.0, 1.0, 0.0)
    [@test(p.scale == 1.5) for p in opfs[[3, 5]]]
    [@test(p.scale == 1.0) for p in opfs[[1, 2, 4, 6]]]
    [@test(p.inclinationAngle == 0.0) for p in opfs]
    [@test(p.inclinationAzimut == 0.0) for p in opfs]
    [@test(p.rotation == 0.0) for p in opfs[[1, 2, 3, 6]]]
    [@test(p.rotation == 1.57) for p in opfs[[4, 5]]]
    @test ops[1].functional_group == "coffee"
    [@test(p.functional_group == "plant") for p in opfs[2:end]]
end

@testset "read_ops applies inclination transforms" begin
    files_dir = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files")
    mktempdir() do tmp
        cp(joinpath(files_dir, "simple_plant.opf"), joinpath(tmp, "simple_plant.opf"); force=true)

        x, y, z = 0.4, -0.2, 0.3
        scale = 1.25
        inclination_azimut = 0.35
        inclination_angle = 0.42
        rotation = 0.17

        ops_path = joinpath(tmp, "scene_inclined.ops")
        open(ops_path, "w") do io
            println(io, "T 0.0 0.0 0.0 2.0 1.0 flat")
            println(io, "#[Archimed] plant")
            println(
                io,
                "1\t1\tsimple_plant.opf\t$(x)\t$(y)\t$(z)\t$(scale)\t$(inclination_azimut)\t$(inclination_angle)\t$(rotation)",
            )
        end

        scene = @test_nowarn read_ops(ops_path)
        opf = only(children(scene))

        axis = SVector(-sin(inclination_azimut), cos(inclination_azimut), 0.0)
        axis = axis / norm(axis)

        expected_tf = PlantGeom.IdentityTransformation()
        expected_tf = PlantGeom.compose_lr(expected_tf, PlantGeom.LinearMap(PlantGeom.RotZ(rotation)))
        expected_tf = PlantGeom.compose_lr(expected_tf, PlantGeom.LinearMap(Diagonal(SVector(scale, scale, scale))))
        expected_tf = PlantGeom.compose_lr(
            expected_tf,
            PlantGeom.LinearMap(PlantGeom.RotMatrix(PlantGeom.AngleAxis(inclination_angle, axis[1], axis[2], axis[3]))),
        )
        expected_tf = PlantGeom.compose_lr(expected_tf, PlantGeom.Translation(x, y, z))

        got_mat = PlantGeom.transformation_matrix4(opf.scene_transformation)
        expected_mat = PlantGeom.transformation_matrix4(expected_tf)
        @test maximum(abs.(got_mat .- expected_mat)) < 1e-12
    end
end

legacy_file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene_legacy.ops")
@testset "read_ops relaxed legacy layout" begin
    ops = @test_nowarn read_ops(legacy_file; relaxed=true, assume_scale_column=false, opf_scale=1.0, gwa_scale=0.01)
    @test length(children(ops)) == 2
    opfs = children(ops)
    @test opfs[1].scale == 1.0
    @test opfs[2].scale == 0.01
    @test opfs[1].functional_group == "coffee"
    @test opfs[2].functional_group == "pavement"
end

nogroup_file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene_no_archimed.ops")
@testset "read_ops without Archimed header" begin
    ops = @test_nowarn read_ops(nogroup_file)
    @test length(children(ops)) == 1
    @test children(ops)[1].functional_group == ""
    @test_throws ErrorException read_ops(nogroup_file; require_functional_group=true)
end
