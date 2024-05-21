tmp_file = tempname()
@testset "write_opf: read, write, read again and compare -> simple_plant" begin
    scene_dimensions = (Meshes.Point(0.0, 0.0, 0.0), Meshes.Point(100.0, 100.0, 0.0))
    positions = [Meshes.Point(50.0, 50.0, 50.0), Meshes.Point(60.0, 60.0, 60.0), Meshes.Point(70.0, 70.0, 70.0)]
    object_table = [
        (sceneID=1, plantID=p, filePath="opf/plant_$p.opf", pos=positions[p], functional_group="plant", rotation=0.1) for p in 1:3
    ]
    @test_nowarn write_ops(tmp_file, scene_dimensions, object_table)

    ops = @test_nowarn read_ops_file(tmp_file)
    @test ops.scene_dimensions == scene_dimensions

    object_table_cols = Tables.columns(object_table)
    ops_object_table_cols = Tables.columns(ops.object_table)
    for col in Tables.columnnames(object_table_cols)
        @test ops_object_table_cols[col] == object_table_cols[col]
    end

    @test ops_object_table_cols.inclinationAngle == fill(0.0, 3)
    @test ops_object_table_cols.inclinationAzimut == fill(0.0, 3)
    @test ops_object_table_cols.scale == fill(1, 3)
end