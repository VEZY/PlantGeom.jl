mtg = read_opf("files/simple_plant.opf", attr_type=Dict)

@testset "read_opf: simple_plant.opf -> attributes" begin
    @test length(mtg) == 7
    @test haskey(mtg, :ref_meshes)
    @test sort(names(mtg)) == [:FileName, :Length, :Width, :XEuler, :geometry, :ref_meshes]
    @test descendants(mtg, :Length) == Any[nothing, nothing, 0.1f0, 0.2f0, 0.1f0, 0.2f0]
    @test descendants(mtg, :Width) == Any[nothing, nothing, 0.02f0, 0.1f0, 0.02f0, 0.1f0]
    @test descendants(mtg, :FileName) == Any["ArchiTree", nothing, nothing, nothing, nothing, nothing]
    @test descendants(mtg, :XEuler) == Any[nothing, nothing, nothing, nothing, 180.0f0, nothing]
end

@testset "read_opf: simple_plant.opf -> ref. meshes" begin
    ref_meshes = mtg[:ref_meshes]
    @test length(ref_meshes) == 2
    first_mesh = ref_meshes[1]
    @test isa(first_mesh.mesh, Meshes.SimpleMesh)
    @test length(first_mesh.mesh) == 50
    @test isa(first_mesh.material, Phong)
    @test first_mesh.name == "Mesh0"
    @test eltype(first_mesh.normals) <: Meshes.Vec
    @test length(first_mesh.normals) == 50
    @test first_mesh.taper == true
    @test eltype(first_mesh.texture_coords) <: Meshes.Point
    @test length(first_mesh.texture_coords) == 50
end

@testset "read_opf: simple_plant.opf -> meshes" begin
    Internode = get_node(mtg, 4)

    @test sort(collect(keys(Internode))) == [:Length, :Width, :geometry]
    @test sort(names(Internode)) == [:Length, :Width, :XEuler, :geometry]
    @test isa(Internode[:geometry], PlantGeom.Geometry)

    geom = Internode[:geometry]
    @test isnothing(geom.mesh)
    @test geom.ref_mesh === mtg[:ref_meshes][1] #! update this number 
    @test typeof(geom.transformation[1]) <: Affine{3,SMatrix{3,3,Float64,9},<:Meshes.Vec}
    @test isa(geom.transformation[2], Translate{3})
    @test [p.val for p in to(geom.transformation(Meshes.Point(1.0, 1.0, 1.0)))] ≈ [-1.0, 1.0, 10.0] atol = 1.0e-6
    # NB: last one is 10 because there is some tappering
end

@testset "read_opf: read coffee.opf" begin
    mtg = read_opf("files/coffee.opf", attr_type=Dict)
    @test length(mtg) == 4191
    @test sort(get_attributes(mtg)) ==
          [
        :Area, :File, :FileName, :Length, :Name, :Phyllotaxy, :Plagiotropy, :Plot, :StiffnessAngle,
        :Stifness, :Treatment, :Variety, :Width, :XEuler, :XInsertionAngle, :YInsertionAngle,
        :geometry, :ref_meshes]

    @test Float64(sum(descendants(mtg, :Area, ignore_nothing=true))) ≈ 77961.421 atol = 1e-3
end
