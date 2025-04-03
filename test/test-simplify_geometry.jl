
@testset "merge_children_geometry!" begin
    @testset "delete= :none" begin
        # Load the example OPF file
        mtg = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf"))
        @test !haskey(mtg[1], :geometry)
        # Simplify geometry from "Metamer" and "Leaf" to "Axis" 
        merge_children_geometry!(mtg; from=["Metamer", "Leaf"], into="Axis", delete=:none, child_link_fun=new_child_link)

        # Verify the transformation
        @test haskey(mtg[1], :geometry)

        metamer = get_node(mtg, 2879)
        @test !isnothing(metamer) # The metamer still exists
        @test !isempty(children(metamer)) # Its leaf too
        @test symbol(metamer[1]) == "Leaf"
        @test length(descendants(mtg, symbol=["Metamer", "Leaf"])) == 4032
        @test haskey(metamer, :geometry) # The geometry is still there
        @test haskey(metamer[1], :geometry)
    end

    @testset "delete= :geometry" begin
        # Load the example OPF file
        mtg = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf"))
        @test !haskey(mtg[1], :geometry)
        # Simplify geometry from "Metamer" and "Leaf" to "Axis" 
        merge_children_geometry!(mtg; from=["Metamer", "Leaf"], into="Axis", delete=:geometry, child_link_fun=new_child_link)

        # Verify the transformation
        @test haskey(mtg[1], :geometry) # Axis has geometry
        metamer = get_node(mtg, 2879)
        @test !haskey(metamer, :geometry) # The metamer does not have geometry anymore
        @test !haskey(metamer[1], :geometry) # Neither the leaf
        @test !isnothing(metamer) # The metamer still exists
        @test !isempty(children(metamer)) # Its leaf too
        @test symbol(metamer[1]) == "Leaf"
        @test length(descendants(mtg, symbol=["Metamer", "Leaf"])) == 4032
    end

    @testset "with node deletion" begin
        # Load the example OPF file
        mtg = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf"))
        @test !haskey(mtg[1], :geometry)
        # Simplify geometry from "Metamer" and "Leaf" to "Axis" 
        merge_children_geometry!(mtg; from=["Metamer", "Leaf"], into="Axis", delete=:nodes, child_link_fun=new_child_link)

        # Verify the transformation
        @test haskey(mtg[1], :geometry)

        # Check that the nodes were deleted
        @test descendants(mtg, symbol=["Metamer", "Leaf"]) |> isempty
    end
end