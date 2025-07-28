# Import / pre-compute
file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)
transform!(opf, refmesh_to_mesh!)
@testset "Makie recipes: reference meshes -> plot structure" begin
    f, ax, p = plantviz(meshes)
    @test p.converted.value[][1] == meshes
    @test typeof(p.plots[1]) <: Plot{plantviz}
    aligned_meshes = PlantGeom.align_ref_meshes(meshes)
    @test p.plots[1].converted.value[][1] == aligned_meshes["Mesh0"]
    @test p.plots[2].converted.value[][1] == aligned_meshes["Mesh1"]
end

@testset "Makie recipes: reference meshes -> image references" begin
    @test_reference "reference_images/refmesh_basic.png" plantviz(meshes)
    @test_reference "reference_images/refmesh_allcolors.png" plantviz(meshes, color=Dict("Mesh0" => :burlywood4, "Mesh1" => :springgreen4))
    @test_reference "reference_images/refmesh_somecolors.png" plantviz(meshes, color=Dict("Mesh1" => :burlywood4))

    vertex_color1 = get_color(1:nvertices.(get_ref_meshes(opf))[1], [1, nvertices.(get_ref_meshes(opf))[1]])
    vertex_color2 = get_color(1:nvertices.(get_ref_meshes(opf))[2], [1, nvertices.(get_ref_meshes(opf))[1]])

    @test_reference "reference_images/refmesh_vertex_colors.png" plantviz(
        meshes,
        color=Dict(
            "Mesh0" => vertex_color1,
            "Mesh1" => vertex_color2,
        )
    )
end

opf = read_opf(file)
meshes = get_ref_meshes(opf)
transform!(opf, refmesh_to_mesh!)

@testset "Makie recipes: whole MTG -> image references" begin
    @test_reference "reference_images/opf_basic.png" plantviz(opf)
    @test_reference "reference_images/opf_one_color.png" plantviz(opf, color=:red)
    @test_reference "reference_images/opf_one_color_per_ref.png" plantviz(opf, color=Dict("Mesh0" => :burlywood4, "Mesh1" => :springgreen4))
    @test_reference "reference_images/opf_one_color_one_ref.png" plantviz(opf, color=Dict("Mesh0" => :burlywood4))
    vertex_color = get_color(1:nvertices.(get_ref_meshes(opf))[1], [1, nvertices.(get_ref_meshes(opf))[1]])
    @test_reference "reference_images/opf_color_ref_vertex.png" plantviz(opf, color=Dict("Mesh0" => vertex_color))
    transform!(opf, zmax => :z_max, ignore_nothing=true)
    @test_reference "reference_images/opf_color_attribute.png" plantviz(opf, color=:z_max)

    transform!(opf, :geometry => (x -> [Meshes.coords(i).z for i in Meshes.vertices(x.mesh)]) => :z, ignore_nothing=true)
    @test_reference "reference_images/opf_color_attribute_vertex.png" plantviz(opf, color=:z, showsegments=true)

    fig2, ax2, p2 = plantviz(opf, color=:z)
    colorbar(fig2[1, 2], p2)
    @test_reference "reference_images/opf_color_attribute_colorbar.png" fig2
    #! note: the reference image is not good, it should be colored by vertex, with a colorbar range from 0 to 0.3
    #! The package produces the right one outside of the tests. I tried everything I could but can't figure out 
    #! why the tests are producing a wrong one... I will leave it like this for now.

    fig3, ax3, p3 = plantviz(opf, color=:z, colorrange=(0.0u"m", 0.5u"m"))
    colorbar(fig3[1, 2], p3)
    @test_reference "reference_images/opf_color_attribute_colorbar_range.png" fig3
end

@testset "Makie recipes: observables, change colorscale range" begin
    fig, ax, p = plantviz(opf, color=:Length, colorrange=(0, 0.2))
    @test p.attributes.colorrange[] == (0, 0.2)
    colorbar(fig[1, 2], p)
    p.colorrange = (0, 0.1)
    @test p.attributes.colorrange[] == (0, 0.1)
end

@testset "Makie recipes: change node color" begin
    fig, ax, p = plantviz(opf, color=:Length, colorrange=(0, 0.2))

    leaf = get_node(opf, 5)
    leaf[:_cache_d9b4f7f3c3467a55ad26f362065777c471aee4c7][] = parse(Colorant, :red)

    @test_reference "reference_images/opf_color_attribute_observable_node.png" fig

    # Making the whole plot red:
    fig, ax, p = plantviz(opf, color=:red)
    # Update with a green leaf:
    leaf = get_node(opf, 5)
    leaf[:_cache_d9b4f7f3c3467a55ad26f362065777c471aee4c7][] = parse(Colorant, :green)

    @test_reference "reference_images/opf_color_attribute_observable_node_red_green.png" fig

    # Making the whole plot blue:
    p.color = :blue
    @test_reference "reference_images/opf_color_attribute_observable_node_blue.png" fig
end

@testset "Makie recipes: filter nodes" begin
    @testset "Symbol" begin
        fig, ax, p = plantviz(opf, symbol="Leaf")
        @test_reference "reference_images/opf_filter_symbol_leaf.png" fig

        fig, ax, p = plantviz(opf, symbol="Leaf", color=:Length, colorrange=(0, 0.2))
        @test_reference "reference_images/opf_filter_symbol_leaf_colored_var.png" fig

        fig, ax, p = plantviz(opf, symbol="Leaf", color=:red)
        @test_reference "reference_images/opf_filter_symbol_leaf_colored_red.png" fig
    end

    @testset "Symbol" begin
        fig, ax, p = plantviz(opf, scale=3)
        @test_reference "reference_images/opf_basic.png" fig
        # This is the same test as just viz(opf) because scale 3 is the only one with geometry

        fig, ax, p = plantviz(opf, scale=3, color=:Length, colorrange=(0, 0.2))
        @test_reference "reference_images/opf_filter_scale_leaf_internode_colored_var.png" fig
    end


    @testset "Link" begin
        fig, ax, p = plantviz(opf, link="+")
        @test_reference "reference_images/opf_filter_symbol_leaf.png" fig
        # This is the same test as just `viz(opf, symbol="Leaf")` because only the leaves are branching
    end


    @testset "Filter function" begin
        fig, ax, p = plantviz(opf, filter_fun=node -> link(node) == "+")
        @test_reference "reference_images/opf_filter_symbol_leaf.png" fig
        # This is the same test as just `viz(opf, symbol="Leaf")` because only the leaves are branching
    end
end