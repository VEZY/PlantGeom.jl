tmp_file = tempname()
@testset "write_opf: read, write, read again and compare -> simple_plant" begin
    mtg = read_opf("files/simple_plant.opf", Dict)
    PlantGeom.write_opf(tmp_file, mtg)
    mtg2 = read_opf(tmp_file, Dict)
    # Compare each node one by one:
    @test MultiScaleTreeGraph.traverse(mtg, node -> node) == MultiScaleTreeGraph.traverse(mtg2, node -> node)
end

@testset "write_opf: read, write, read again and compare -> coffee" begin
    mtg = read_opf("files/coffee.opf", Dict)
    PlantGeom.write_opf(tmp_file, mtg)
    mtg2 = read_opf(tmp_file, Dict)
    # Compare each node one by one:
    @test MultiScaleTreeGraph.traverse(mtg, node -> node) == MultiScaleTreeGraph.traverse(mtg2, node -> node)
end