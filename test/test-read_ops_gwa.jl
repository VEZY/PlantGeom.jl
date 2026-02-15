file_gwa = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene_gwa.ops")
file_mix = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene_mix.ops")

@testset "read_ops_file with gwa" begin
    ops = @test_nowarn read_ops_file(file_gwa)
    @test length(ops.object_table) == 1
    row = first(Tables.rows(ops.object_table))
    @test row.filePath == "pave1x1.gwa"
    @test row.functional_group == "pavement"
end

@testset "read_ops with gwa and mixed ops" begin
    gwa_scene = @test_nowarn read_ops(file_gwa)
    @test length(children(gwa_scene)) == 1
    @test children(gwa_scene)[1].filePath == "pave1x1.gwa"

    mixed_scene = @test_nowarn read_ops(file_mix)
    @test length(children(mixed_scene)) == 2
    @test Set([c.filePath for c in children(mixed_scene)]) == Set(["coffee.opf", "pave1x1.gwa"])
end
