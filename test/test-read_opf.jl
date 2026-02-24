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
    @test isa(first_mesh.mesh, GeometryBasics.AbstractMesh{3})
    @test PlantGeom.nvertices(first_mesh) == 50
    @test isa(first_mesh.material, Phong)
    @test first_mesh.name == "Mesh0"
    @test eltype(first_mesh.normals) <: GeometryBasics.Vec{3,Float64}
    @test length(first_mesh.normals) == 50
    @test first_mesh.taper == true
    @test eltype(first_mesh.texture_coords) <: GeometryBasics.Point{2,Float64}
    @test length(first_mesh.texture_coords) == 50
end

@testset "read_opf: simple_plant.opf -> meshes" begin
    Internode = get_node(mtg, 4)

    @test sort(collect(keys(Internode))) == [:Length, :Width, :XEuler, :geometry]
    @test sort(names(Internode)) == [:Length, :Width, :XEuler, :geometry]
    @test isa(Internode[:geometry], PlantGeom.Geometry)

    geom = Internode[:geometry]
    @test geom.ref_mesh === mtg[:ref_meshes][1] #! update this number 
    @test geom.transformation(SVector{3,Float64}(0.0, 0.0, 0.0)) isa SVector{3,Float64}
    @test collect(geom.transformation(SVector{3,Float64}(1.0, 1.0, 1.0))) ≈ [-1.0, 1.0, 10.0] atol = 1.0e-6
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

@testset "read_opf: triangulate polygon faces and fallback material" begin
    quad_file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "quad_empty_material.opf")
    mtg_quad = @test_nowarn read_opf(quad_file, attr_type=Dict)
    @test length(mtg_quad[:ref_meshes]) == 1
    @test PlantGeom.nelements(mtg_quad[:ref_meshes][1]) == 2
    @test isa(mtg_quad[:ref_meshes][1].material, Phong)
end
