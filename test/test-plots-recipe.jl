@testset "Plots recipe" begin
    mtg = read_opf("files/simple_plant.opf", Dict)

    recipe = RecipesBase.apply_recipe(Dict{Symbol,Any}(), mtg)

    @test length(recipe) == length(mtg)
    #? NB: both should be equal because 6 lines (all except first point have an edge),
    #? and 1 scatter.

    @test recipe[1].plotattributes == Dict{Symbol,Any}(:label => "", :seriescolor => :black, :seriestype => :line)
    @test recipe[1].args == ([0.0, 0.0], [0.0, 0.2]) # coordinates of the two vertex for the edge
    @test recipe[6].args == ([0.0, 0.7071067811865475], [1.6, 2.3071067811865476]) # same, last one

    df_coordinates = PlantGeom.mtg_coordinates_df(mtg, force=true)

    @test recipe[7].args[1] == df_coordinates.XX
    @test recipe[7].plotattributes == Dict{Symbol,Any}(
        :color => :black,
        :palette => colorschemes[:viridis],
        :label => "",
        :hover => [
            "name: `node_1`, link: `/`, symbol: `Scene`, index: `1`",
            "name: `node_2`, link: `/`, symbol: `Individual`, index: `2`",
            "name: `node_3`, link: `/`, symbol: `Axis`, index: `3`",
            "name: `node_4`, link: `/`, symbol: `Internode`, index: `4`",
            "name: `node_5`, link: `+`, symbol: `Leaf`, index: `5`",
            "name: `node_6`, link: `<`, symbol: `Internode`, index: `6`",
            "name: `node_7`, link: `+`, symbol: `Leaf`, index: `7`",
        ],
        :seriestype => :scatter,
        :colorbar_entry => false
    )
end
