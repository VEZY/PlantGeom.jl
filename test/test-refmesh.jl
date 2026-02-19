panel_dimensions = [100.0, 1000.0]
panel_points = GeometryBasics.Point{3,Float64}.([(0.0, 0.0, 0.0), (0.0, panel_dimensions[2], 0.0), (panel_dimensions..., 0.0), (panel_dimensions[1], 0.0, 0.0)])
panel_faces = GeometryBasics.TriangleFace{Int}.([(1, 2, 3), (3, 4, 1)])
panel_mesh = GeometryBasics.Mesh(panel_points, panel_faces)

@testset "RefMesh" begin
    refmesh = @test_nowarn PlantGeom.RefMesh("Panel", panel_mesh)
    @test PlantGeom.nvertices(refmesh) == 4
    @test PlantGeom.nelements(refmesh) == 2
    @test refmesh.material == RGB(220 / 255, 220 / 255, 220 / 255)
    @test refmesh.mesh == panel_mesh
    @test refmesh.normals == PlantGeom.normals_vertex(refmesh)
    @test refmesh.taper == false
    @test isnothing(refmesh.texture_coords)
end
