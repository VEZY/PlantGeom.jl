file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene.ops")
@testset "read_ops" begin
    ops = @test_nowarn read_ops(file)
    @test ops.scene_dimensions == (Meshes.Point(0.0, 0.0, 0.0), Meshes.Point(2.0, 1.0, 0.0))
    @test length(ops.ref_meshes) == 5
    #Note: there are only 4 ref_meshes because the same opf file is used for the simple_plants,
    # so we can optimize it by only using the common ones.
    opfs = children(ops)
    length(opfs) == 6
    opfs[1].filePath == "coffee.opf"
    [@test(p.filePath == "simple_plant.opf") for p in opfs[2:end]]
    @test [p.plantID for p in opfs] == collect(1:6)
    @test [p.sceneID for p in opfs] == fill(1, 6)
    @test opfs[1].pos == Meshes.Point(0.0, 0.0, 0.0)
    @test opfs[6].pos == Meshes.Point(2.0, 1.0, 0.0)
    [@test(p.scale == 1.5) for p in opfs[[3, 5]]]
    [@test(p.scale == 1.0) for p in opfs[[1, 2, 4, 6]]]
    [@test(p.inclinationAngle == 0.0) for p in opfs]
    [@test(p.inclinationAzimut == 0.0) for p in opfs]
    [@test(p.rotation == 0.0) for p in opfs[[1, 2, 3, 6]]]
    [@test(p.rotation == 1.57) for p in opfs[[4, 5]]]
    @test ops[1].functional_group == "coffee"
    [@test(p.functional_group == "plant") for p in opfs[2:end]]
end