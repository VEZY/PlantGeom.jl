file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene.ops")
@testset "read_ops_file" begin
    ops = @test_nowarn read_ops_file(file)
    @test ops.scene_dimensions == (PlantGeom.Point3(0.0, 0.0, 0.0), PlantGeom.Point3(2.0, 1.0, 0.0))
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
        PlantGeom.Point3(0.0, 0.0, 0.0),
        PlantGeom.Point3(1.0, 0.0, 0.0),
        PlantGeom.Point3(2.0, 0.0, 0.0),
        PlantGeom.Point3(0.0, 1.0, 0.0),
        PlantGeom.Point3(1.0, 1.0, 0.0),
        PlantGeom.Point3(2.0, 1.0, 0.0)
    ]
end

legacy_file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene_legacy.ops")
@testset "read_ops_file relaxed legacy layout" begin
    ops = @test_nowarn read_ops_file(legacy_file; relaxed=true, assume_scale_column=false, opf_scale=1.0, gwa_scale=0.01)
    @test ops.scene_dimensions == (PlantGeom.Point3(0.0, 0.0, 0.0), PlantGeom.Point3(2.0, 1.0, 0.0))
    @test length(ops.object_table) == 2
    table = Tables.columntable(ops.object_table)
    @test table.scale == [1.0, 0.01]
    @test table.rotation == [0.0, 0.0]
    @test table.functional_group == ["coffee", "pavement"]
end

nogroup_file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene_no_archimed.ops")
@testset "read_ops_file without Archimed header" begin
    ops = @test_nowarn read_ops_file(nogroup_file)
    @test length(ops.object_table) == 1
    @test only(Tables.columntable(ops.object_table).functional_group) == ""
    @test_throws ErrorException read_ops_file(nogroup_file; require_functional_group=true)
end
