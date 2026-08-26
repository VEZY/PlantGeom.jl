@testset "write_opf: skips transient scene cache attributes" begin
    mtg = read_opf("files/simple_plant.opf")
    mtg[:_scene_version] = 3
    mtg[:_scene_cache] = (hash=UInt(1), mesh="cached-mesh", face2node=[1, 2, 3])

    tmp_file = tempname() * ".opf"
    @test_nowarn write_opf(tmp_file, mtg)

    raw = read(tmp_file, String)
    @test !occursin("_scene_cache", raw)
    @test !occursin("_scene_version", raw)

    reloaded = read_opf(tmp_file)
    @test !haskey(reloaded, :_scene_cache)
    @test !haskey(reloaded, :_scene_version)
end

@testset "write_opf: skips PlantSimEngine runtime status without mutating source geometry" begin
    mtg = read_opf("files/simple_plant.opf")
    source_nodes = collect(traverse(mtg, identity))
    geometry_position = findfirst(PlantGeom.has_geometry, source_nodes)
    @test geometry_position !== nothing
    geometry_node = source_nodes[something(geometry_position)]
    root_status = PlantSimEngine.Status(node=mtg, runtime_value=11.0)
    geometry_status = PlantSimEngine.Status(node=geometry_node, runtime_value=17.0)
    mtg[:plantsimengine_status] = root_status
    geometry_node[:plantsimengine_status] = geometry_status
    mtg[:UserScalar] = 23

    source_geometry = geometry_node[:geometry]
    source_geometry_matrix = copy(
        get_transformation_matrix(source_geometry.transformation),
    )
    source_mesh = refmesh_to_mesh(geometry_node)
    root_keys = Set(keys(mtg))
    geometry_keys = Set(keys(geometry_node))

    tmp_file = tempname() * ".opf"
    @test_nowarn write_opf(tmp_file, mtg)

    raw = read(tmp_file, String)
    @test !occursin("plantsimengine_status", raw)
    reloaded = read_opf(tmp_file)
    @test all(
        node -> !haskey(node, :plantsimengine_status),
        traverse(reloaded, identity),
    )

    @test Set(keys(mtg)) == root_keys
    @test Set(keys(geometry_node)) == geometry_keys
    @test mtg[:plantsimengine_status] === root_status
    @test geometry_node[:plantsimengine_status] === geometry_status
    @test mtg[:UserScalar] == 23
    @test geometry_node[:geometry] === source_geometry
    @test get_transformation_matrix(source_geometry.transformation) ==
          source_geometry_matrix

    reloaded_node = collect(traverse(reloaded, identity))[something(geometry_position)]
    @test PlantGeom.has_geometry(reloaded_node)
    @test _approx_mesh(source_mesh, refmesh_to_mesh(reloaded_node))
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

            reloaded = read_opf(path)
            @test !haskey(reloaded, :_scene_cache)
            @test !haskey(reloaded, :_scene_version)
        end
    end
end
