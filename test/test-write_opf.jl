tmp_file = tempname()
@testset "write_opf: read, write, read again and compare -> simple_plant" begin
    mtg = read_opf("files/simple_plant.opf", attr_type=Dict)
    PlantGeom.write_opf(tmp_file, mtg)
    mtg2 = read_opf(tmp_file, attr_type=Dict)
    # Compare each node one by one:
    @test all([i == j for (i, j) in zip(MultiScaleTreeGraph.traverse(mtg, node -> node), MultiScaleTreeGraph.traverse(mtg2, node -> node))])
end

@testset "write_opf: read, write, read again and compare -> coffee" begin
    mtg = read_opf("files/coffee.opf", attr_type=Dict)
    PlantGeom.write_opf(tmp_file, mtg)
    mtg2 = read_opf(tmp_file, attr_type=Dict)
    # Compare each node one by one:
    comp = MultiScaleTreeGraph.traverse(mtg, node -> node) == MultiScaleTreeGraph.traverse(mtg2, node -> node)
    @test comp
end