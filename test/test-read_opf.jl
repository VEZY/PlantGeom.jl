mtg = read_opf("files/simple_plant.opf", attr_type=Dict)

@testset "read_opf: simple_plant.opf -> attributes" begin
    @test length(mtg) == 7
    @test haskey(mtg, :ref_meshes)
    @test sort(names(mtg)) == [:FileName, :Length, :Width, :XEuler, :geometry, :ref_meshes, :source_topology_id]
    @test descendants(mtg, :Length) == Any[nothing, nothing, 0.1f0, 0.2f0, 0.1f0, 0.2f0]
    @test descendants(mtg, :Width) == Any[nothing, nothing, 0.02f0, 0.1f0, 0.02f0, 0.1f0]
    @test descendants(mtg, :FileName) == Any["ArchiTree", nothing, nothing, nothing, nothing, nothing]
    @test descendants(mtg, :XEuler) == Any[nothing, nothing, nothing, nothing, 180.0f0, nothing]
end

@testset "read_opf: simple_plant.opf -> ref. meshes" begin
    ref_meshes = mtg[:ref_meshes]
    @test length(ref_meshes) == 2
    # Use the actual keys from the file (0 and 1) instead of assuming 1-based indexing
    mesh_keys = sort(collect(keys(ref_meshes)))
    first_mesh = ref_meshes[mesh_keys[1]]  # First key (0)
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

    @test sort(collect(keys(Internode))) == [:Length, :Width, :XEuler, :geometry, :source_topology_id]
    @test sort(names(Internode)) == [:Length, :Width, :XEuler, :geometry, :source_topology_id]
    @test isa(Internode[:geometry], PlantGeom.Geometry)

    geom = Internode[:geometry]
    @test geom.ref_mesh === mtg[:ref_meshes][0] # Updated to use actual ID (0) instead of 1-based index
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
        :geometry, :ref_meshes, :source_topology_id]

    @test Float64(sum(descendants(mtg, :Area, ignore_nothing=true))) ≈ 77961.421 atol = 1e-3
end

@testset "read_opf: triangulate polygon faces and fallback material" begin
    quad_file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "quad_empty_material.opf")
    mtg_quad = @test_nowarn read_opf(quad_file, attr_type=Dict)
    @test length(mtg_quad[:ref_meshes]) == 1
    # Use actual ID (0) instead of 1-based index
    mesh_key = first(keys(mtg_quad[:ref_meshes]))
    @test PlantGeom.nelements(mtg_quad[:ref_meshes][mesh_key]) == 2
    @test isa(mtg_quad[:ref_meshes][mesh_key].material, Phong)
end

@testset "read_opf: dynamic attributes without attributeBDD widen to broader types" begin
    mktempdir() do tmp
        opf_path = joinpath(tmp, "dynamic_missing_attrbdd.opf")
        open(opf_path, "w") do io
            write(
                io,
                """
<?xml version="1.0" encoding="UTF-8"?>
<opf version="2.0" editable="true">
    <meshBDD>
        <mesh name="Quad" shape="" Id="0" enableScale="false">
            <points>0 0 0 100 0 0 100 100 0 0 100 0</points>
            <normals>0 0 1 0 0 1 0 0 1 0 0 1</normals>
            <faces><face Id="0">0 1 2 3</face></faces>
        </mesh>
    </meshBDD>
    <materialBDD></materialBDD>
    <shapeBDD>
        <shape Id="0">
            <name>Quad</name>
            <meshIndex>0</meshIndex>
            <materialIndex>0</materialIndex>
        </shape>
    </shapeBDD>
    <topology class="Plant" scale="1" id="1">
        <Name>Root</Name>
        <decomp class="Axis" scale="2" id="2">
            <DynamicValue>1</DynamicValue>
            <geometry class="Mesh">
                <shapeIndex>0</shapeIndex>
                <mat>1 0 0 0 0 1 0 0 0 0 1 0</mat>
                <dUp>1.0</dUp>
                <dDwn>1.0</dDwn>
            </geometry>
        </decomp>
        <branch class="Axis" scale="2" id="3">
            <DynamicValue>2.5</DynamicValue>
            <geometry class="Mesh">
                <shapeIndex>0</shapeIndex>
                <mat>1 0 0 0 0 1 0 0 0 0 1 0</mat>
                <dUp>1.0</dUp>
                <dDwn>1.0</dDwn>
            </geometry>
            <follow class="Axis" scale="2" id="4">
                <DynamicValue>hello</DynamicValue>
                <geometry class="Mesh">
                    <shapeIndex>0</shapeIndex>
                    <mat>1 0 0 0 0 1 0 0 0 0 1 0</mat>
                    <dUp>1.0</dUp>
                    <dDwn>1.0</dDwn>
                </geometry>
            </follow>
        </branch>
    </topology>
</opf>
"""
            )
        end

        mtg_dyn = @test_nowarn read_opf(opf_path, attr_type=Dict)
        vals = descendants(mtg_dyn, :DynamicValue, ignore_nothing=true)
        @test vals == Any[1, 2.5f0, "hello"]
    end
end

@testset "read_opf: attribute_types overrides OPF or dynamic typing" begin
    mtg_string_len = read_opf("files/simple_plant.opf", attr_type=Dict, attribute_types=Dict("Length" => String))
    length_vals = descendants(mtg_string_len, :Length, ignore_nothing=true)
    @test length_vals == Any["0.1", "0.2", "0.1", "0.2"]
end
