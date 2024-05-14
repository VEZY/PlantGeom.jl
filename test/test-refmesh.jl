
panel_dimensions = [100.0, 1000.0]
panel_points = Meshes.Point.([(0.0, 0.0, 0.0), (0.0, panel_dimensions[2], 0.0), (panel_dimensions..., 0.0), (panel_dimensions[1], 0.0, 0.0)])
# connect the points into N-gon
panel_connec = connect.([(1, 2, 3), (3, 4, 1)], Ngon)
# 3D mesh made of N-gon elements
panel_mesh = SimpleMesh(panel_points, panel_connec)

@testset "RefMesh" begin
    refmesh = @test_nowarn PlantGeom.RefMesh("Panel", panel_mesh)
    @test Meshes.nvertices(refmesh) == 4
    @test Meshes.nelements(refmesh) == 2
    @test refmesh.material == RGB(220 / 255, 220 / 255, 220 / 255)
    @test refmesh.mesh == panel_mesh
    @test refmesh.normals == PlantGeom.normals_vertex(refmesh)
    @test refmesh.taper == false
    @test isnothing(refmesh.texture_coords)
end