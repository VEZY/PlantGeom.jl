file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "pave1x1.gwa")
@testset "read_gwa" begin
    gwa = @test_nowarn read_gwa(file)
    @test length(MultiScaleTreeGraph.children(gwa)) == 1
    @test length(get_ref_meshes(gwa)) == 1
    @test !hasproperty(gwa, :geometry)
    @test !hasproperty(gwa, :source_topology_id)

    node = first(MultiScaleTreeGraph.children(gwa))
    @test MultiScaleTreeGraph.node_id(gwa) != MultiScaleTreeGraph.node_id(node)
    @test node[:source_topology_id] == 2
    mesh = refmesh_to_mesh(node)
    @test nvertices(mesh) == 4
    @test nelements(mesh) == 2
end
