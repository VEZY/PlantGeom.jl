tmp_file = tempname()
@testset "write_opf: read, write, read again and compare -> simple_plant" begin
    mtg = read_opf("files/simple_plant.opf", attr_type=Dict)
    PlantGeom.write_opf(tmp_file, mtg)
    mtg2 = read_opf(tmp_file, attr_type=Dict)

    #! to remove when https://github.com/JuliaML/TransformsBase.jl/issues/8 is fixed
    Base.:(==)(x::TransformsBase.SequentialTransform, y::TransformsBase.SequentialTransform) = x.transforms == y.transforms
    # Note: we only do this in the tests because it is type piracy and we don't want to change the behavior of the package.
    # Compare each node one by one:
    @test MultiScaleTreeGraph.traverse(mtg, node -> node) == MultiScaleTreeGraph.traverse(mtg2, node -> node)
end

@testset "write_opf: read, write, read again and compare -> coffee" begin
    mtg = read_opf("files/coffee.opf", attr_type=Dict)
    PlantGeom.write_opf(tmp_file, mtg)
    mtg2 = read_opf(tmp_file, attr_type=Dict)
    # Compare each node one by one:
    @test MultiScaleTreeGraph.traverse(mtg, node -> node) == MultiScaleTreeGraph.traverse(mtg2, node -> node)
end