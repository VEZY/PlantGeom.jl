file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene.ops")
@testset "read_ops_file" begin
    ops = @test_nowarn read_ops_file(file)
    @test ops.scene_dimensions == (Meshes.Point3(0.0, 0.0, 0.0), Meshes.Point3(2.0, 1.0, 0.0))
    @test length(ops.object_table) == 6
    object_table = Tables.columntable(ops.object_table)
    @test object_table.plantID == collect(1:6)
    @test object_table.functional_group == ["coffee", "plant", "plant", "plant", "plant", "plant"]
    @test object_table.filePath == ["coffee.opf", "simple_plant.opf", "simple_plant.opf", "simple_plant.opf", "simple_plant.opf", "simple_plant.opf"]
    @test object_table.inclinationAngle == fill(0.0, 6)
    @test object_table.inclinationAzimut == fill(0.0, 6)
    @test object_table.rotation == [0.0, 0.0, 0.0, 1.57, 1.57, 0.0]
    @test object_table.scale == [1.0, 1.0, 1.5, 1.0, 1.5, 1.0]
    @test object_table.sceneID == fill(1, 6)
    @test object_table.pos == [
        Meshes.Point3(0.0, 0.0, 0.0),
        Meshes.Point3(1.0, 0.0, 0.0),
        Meshes.Point3(2.0, 0.0, 0.0),
        Meshes.Point3(0.0, 1.0, 0.0),
        Meshes.Point3(1.0, 1.0, 0.0),
        Meshes.Point3(2.0, 1.0, 0.0)
    ]
end