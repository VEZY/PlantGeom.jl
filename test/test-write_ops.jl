tmp_file = tempname()
@testset "write_opf: read, write, read again and compare -> simple_plant" begin
    scene_dimensions = (GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0), GeometryBasics.Point{3,Float64}(100.0, 100.0, 0.0))
    positions = [GeometryBasics.Point{3,Float64}(50.0, 50.0, 50.0), GeometryBasics.Point{3,Float64}(60.0, 60.0, 60.0), GeometryBasics.Point{3,Float64}(70.0, 70.0, 70.0)]
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

@testset "write_ops(scene): round-trip emits OPF/GWA objects" begin
    files_dir = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files")
    source_ops = joinpath(files_dir, "scene_mix.ops")
    scene = read_ops(source_ops)

    mktempdir() do tmp
        out_ops = joinpath(tmp, "scene_roundtrip.ops")
        @test_nowarn write_ops(out_ops, scene)
        @test isfile(out_ops)

        parsed = read_ops_file(out_ops)
        parsed_rows = collect(Tables.rows(parsed.object_table))
        @test length(parsed_rows) == length(children(scene))
        @test parsed.scene_dimensions == scene.scene_dimensions

        emitted_paths = [row.filePath for row in parsed_rows]
        @test all(p -> isfile(joinpath(tmp, p)), emitted_paths)

        emitted_exts = sort(map(p -> lowercase(splitext(p)[2]), emitted_paths))
        source_exts = sort(map(c -> lowercase(splitext(c.filePath)[2]), children(scene)))
        @test emitted_exts == source_exts

        @test [row.sceneID for row in parsed_rows] == [c.sceneID for c in children(scene)]
        @test [row.plantID for row in parsed_rows] == [c.plantID for c in children(scene)]
        @test [row.functional_group for row in parsed_rows] == [c.functional_group for c in children(scene)]
        @test [row.pos for row in parsed_rows] == [c.pos for c in children(scene)]
        @test [row.scale for row in parsed_rows] == [c.scale for c in children(scene)]
        @test [row.rotation for row in parsed_rows] == [c.rotation for c in children(scene)]
        @test [row.inclinationAzimut for row in parsed_rows] == [c.inclinationAzimut for c in children(scene)]
        @test [row.inclinationAngle for row in parsed_rows] == [c.inclinationAngle for c in children(scene)]

        reloaded = read_ops(out_ops)
        ids_source = [
            descendants(c, :source_topology_id; ignore_nothing=true, self=true) for c in children(scene)
        ]
        ids_reloaded = [
            descendants(c, :source_topology_id; ignore_nothing=true, self=true) for c in children(reloaded)
        ]
        @test ids_reloaded == ids_source
    end
end
