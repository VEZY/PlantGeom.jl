@testset "read_opf: simple_plant.opf -> read" begin
    mtg = read_opf("files/simple_plant.opf", Dict)
end

mtg = read_opf("files/simple_plant.opf", Dict)

@testset "read_opf: simple_plant.opf -> attributes" begin
    @test length(mtg) == 7
    @test haskey(mtg.attributes, :ref_meshes)
    @test names(mtg) == [:ref_meshes, :FileName, :geometry, :Length, :Width, :XEuler]
    @test descendants(mtg, :Length) == Any[nothing, nothing, 0.1f0, 0.2f0, 0.1f0, 0.2f0]
    @test descendants(mtg, :Width) == Any[nothing, nothing, 0.02f0, 0.1f0, 0.02f0, 0.1f0]
    @test descendants(mtg, :FileName) == Any["ArchiTree", nothing, nothing, nothing, nothing, nothing]
    @test descendants(mtg, :XEuler) == Any[nothing, nothing, nothing, nothing, 180.0f0, nothing]
end

@testset "read_opf: simple_plant.opf -> ref. meshes" begin
    ref_meshes = mtg[:ref_meshes].meshes
    @test length(ref_meshes) == 2
    first_mesh = ref_meshes[1]
    @test isa(first_mesh.mesh, Meshes.SimpleMesh)
    @test length(first_mesh.mesh) == 50
    @test isa(first_mesh.material, Phong)
    @test first_mesh.name == "Mesh0"
    @test isa(first_mesh.normals, SVector{50,Meshes.Point3})
    @test first_mesh.taper == true
    @test isa(first_mesh.texture_coords, SVector{50,Meshes.Point2})
end

@testset "read_opf: simple_plant.opf -> meshes" begin
    Internode = get_node(mtg, 4)

    @test collect(keys(Internode.attributes)) == [:geometry, :Length, :Width]
    @test isa(Internode[:geometry], PlantGeom.geometry)

    geom = Internode[:geometry]
    @test isnothing(geom.mesh)
    @test geom.ref_mesh === mtg[:ref_meshes].meshes[geom.ref_mesh_index]
    @test isa(geom.transformation, AffineMap{Matrix{Float64},Vector{Float64}})
    @test geom.transformation([1, 1, 1]) ≈ [-1.0, 1.0, 10.0] atol = 1.0e-6
    # NB: last one is 10 because there is some tappering
end

@testset "read_opf: read coffee.opf" begin
    mtg = read_opf("files/coffee.opf", Dict)
    @test length(mtg) == 4191
    @test get_attributes(mtg) ==
          [
        :FileName, :Variety, :ref_meshes, :Plot, :Treatment, :File,
        :Name, :geometry, :XEuler, :Length, :Width, :Stifness, :YInsertionAngle,
        :Plagiotropy, :Phyllotaxy, :StiffnessAngle, :Area, :XInsertionAngle
    ]

    @test sum(descendants(mtg, :Area, ignore_nothing = true)) ≈ 77961.414f0 atol = 1e-6
end
