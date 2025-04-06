mtg = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf"))

@testset "merge_children_geometry!" begin
    @testset "delete= :none" begin
        mtg1 = deepcopy(mtg)
        # Load the example OPF file
        @test !haskey(mtg1[1], :geometry)
        # Simplify geometry from "Metamer" and "Leaf" to "Axis" 
        merge_children_geometry!(mtg1; from=["Metamer", "Leaf"], into="Axis", delete=:none, child_link_fun=new_child_link)

        # Verify the transformation
        @test haskey(mtg1[1], :geometry)

        metamer = get_node(mtg1, 2879)
        @test !isnothing(metamer) # The metamer still exists
        @test !isempty(children(metamer)) # Its leaf too
        @test symbol(metamer[1]) == "Leaf"
        @test length(descendants(mtg1, symbol=["Metamer", "Leaf"])) == 4032
        @test haskey(metamer, :geometry) # The geometry is still there
        @test haskey(metamer[1], :geometry)
    end

    @testset "delete= :geometry" begin
        # Load the example OPF file
        mtg2 = deepcopy(mtg)
        @test !haskey(mtg2[1], :geometry)
        # Simplify geometry from "Metamer" and "Leaf" to "Axis" 
        merge_children_geometry!(mtg2; from=["Metamer", "Leaf"], into="Axis", delete=:geometry, child_link_fun=new_child_link)

        # Verify the transformation
        @test haskey(mtg2[1], :geometry) # Axis has geometry
        metamer = get_node(mtg2, 2879)
        @test !haskey(metamer, :geometry) # The metamer does not have geometry anymore
        @test !haskey(metamer[1], :geometry) # Neither the leaf
        @test !isnothing(metamer) # The metamer still exists
        @test !isempty(children(metamer)) # Its leaf too
        @test symbol(metamer[1]) == "Leaf"
        @test length(descendants(mtg2, symbol=["Metamer", "Leaf"])) == 4032
    end

    @testset "with node deletion" begin
        mtg3 = deepcopy(mtg)
        @test length(mtg3) == length(mtg)
        @test !haskey(mtg3[1], :geometry)
        # Simplify geometry from "Metamer" and "Leaf" to "Axis" 
        merge_children_geometry!(mtg3; from=["Metamer", "Leaf"], into="Axis", delete=:nodes, child_link_fun=new_child_link)

        # Verify the transformation
        @test haskey(mtg3[1], :geometry)
        @test length(mtg3) != length(mtg)

        # Check that the nodes were deleted
        @test descendants(mtg3, symbol=["Metamer", "Leaf"]) |> isempty
    end


    @testset "missing nodes" begin
        # Nothing should happen here
        mtg4 = deepcopy(mtg)
        merge_children_geometry!(mtg4; from=["This", "That"], into="Axis", delete=:nodes, child_link_fun=new_child_link, verbose=false)
        @test length(mtg4) == length(mtg)
        @test all(descendants(mtg4) .== descendants(mtg))
    end
end