file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "pave1x1.gwa")
@testset "read_gwa" begin
    gwa = @test_nowarn read_gwa(file)
    @test length(children(gwa)) == 1
    @test length(get_ref_meshes(gwa)) == 1

    node = first(children(gwa))
    mesh = refmesh_to_mesh(node)
    @test nvertices(mesh) == 4
    @test nelements(mesh) == 2
end
