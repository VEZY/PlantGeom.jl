@testset "write_opf: skips transient scene cache attributes" begin
    mtg = read_opf("files/simple_plant.opf", attr_type=Dict)
    mtg[:_scene_version] = 3
    mtg[:_scene_cache] = (hash=UInt(1), mesh="cached-mesh", face2node=[1, 2, 3])

    tmp_file = tempname() * ".opf"
    @test_nowarn write_opf(tmp_file, mtg)

    raw = read(tmp_file, String)
    @test !occursin("_scene_cache", raw)
    @test !occursin("_scene_version", raw)

    reloaded = read_opf(tmp_file, attr_type=Dict)
    @test !haskey(reloaded, :_scene_cache)
    @test !haskey(reloaded, :_scene_version)
end

@testset "write_ops: skips transient scene cache attributes in emitted OPF objects" begin
    files_dir = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files")
    source_ops = joinpath(files_dir, "scene_mix.ops")
    scene = read_ops(source_ops)

    for object_root in children(scene)
        object_root[:_scene_version] = 5
        object_root[:_scene_cache] = (hash=UInt(2), mesh="cached-mesh", face2node=[1, 2, 3])
    end

    mktempdir() do tmp
        out_ops = joinpath(tmp, "scene_cached.ops")
        @test_nowarn write_ops(out_ops, scene)

        parsed = read_ops_file(out_ops)
        emitted_opf_paths = [
            joinpath(tmp, row.filePath) for row in Tables.rows(parsed.object_table)
            if lowercase(splitext(row.filePath)[2]) == ".opf"
        ]

        @test !isempty(emitted_opf_paths)

        for path in emitted_opf_paths
            raw = read(path, String)
            @test !occursin("_scene_cache", raw)
            @test !occursin("_scene_version", raw)

            reloaded = read_opf(path, attr_type=Dict)
            @test !haskey(reloaded, :_scene_cache)
            @test !haskey(reloaded, :_scene_version)
        end
    end
end
