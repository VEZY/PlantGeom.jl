# Import / pre-compute
file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)
transform!(opf, refmesh_to_mesh!)
@testset "Makie recipes: reference meshes -> plot structure" begin
    f, ax, p = viz(meshes)
    @test p.converted[1].val == meshes
    @test typeof(p.plots[1]) == Plot{Meshes.viz,Tuple{Meshes.SimpleMesh{3,Float64,Vector{Meshes.Point3},Meshes.SimpleTopology{Meshes.Connectivity}}}}
    aligned_meshes = PlantGeom.align_ref_meshes(meshes)
    @test p.plots[1].converted[1][] == aligned_meshes[1]
    @test p.plots[2].converted[1][] == aligned_meshes[2]
end

@testset "Makie recipes: reference meshes -> image references" begin
    @test_reference "reference_images/refmesh_basic.png" viz(meshes)
    @test_reference "reference_images/refmesh_allcolors.png" viz(meshes, color=Dict(1 => :burlywood4, 2 => :springgreen4))
    @test_reference "reference_images/refmesh_somecolors.png" viz(meshes, color=Dict(2 => :burlywood4))

    vertex_color1 = get_color(1:nvertices(get_ref_meshes(opf))[1], [1, nvertices(get_ref_meshes(opf))[1]])
    vertex_color2 = get_color(1:nvertices(get_ref_meshes(opf))[2], [1, nvertices(get_ref_meshes(opf))[1]])

    @test_reference "reference_images/refmesh_vertex_colors.png" viz(
        meshes,
        color=Dict(
            1 => vertex_color1,
            2 => vertex_color2,
        )
    )
end


@testset "Makie recipes: whole MTG -> image references" begin
    @test_reference "reference_images/opf_basic.png" viz(opf)
    @test_reference "reference_images/opf_one_color.png" viz(opf, color=:red)
    @test_reference "reference_images/opf_one_color_per_ref.png" viz(opf, color=Dict(1 => :burlywood4, 2 => :springgreen4))
    @test_reference "reference_images/opf_one_color_one_ref.png" viz(opf, color=Dict(1 => :burlywood4))
    vertex_color = get_color(1:nvertices(get_ref_meshes(opf))[1], [1, nvertices(get_ref_meshes(opf))[1]])
    @test_reference "reference_images/opf_color_ref_vertex.png" viz(opf, color=Dict(1 => vertex_color), color_vertex=true)
    transform!(opf, zmax => :z_max, ignore_nothing=true)
    @test_reference "reference_images/opf_color_attribute.png" viz(opf, color=:z_max)

    transform!(opf, :geometry => (x -> [i.coords[3] for i in x.mesh.vertices]) => :z, ignore_nothing=true)
    @test_reference "reference_images/opf_color_attribute_vertex.png" viz(opf, color=:z, showfacets=true, color_vertex=true)

    fig, ax, p = viz(opf, color=:z)
    colorbar(fig[1, 2], p)
    @test_reference "reference_images/opf_color_attribute_colorbar.png" fig

    fig, ax, p = viz(opf, color=:z, color_range=(0, 50))
    colorbar(fig[1, 2], p)
    @test_reference "reference_images/opf_color_attribute_colorbar_range.png" fig
end

@testset "Makie recipes: observables, change colorscale range" begin
    fig, ax, p = viz(opf, color=:Length, color_range=(0, 0.2))
    @test p.attributes.color_range[] == (0, 0.2)
    colorbar(fig[1, 2], p)
    p.color_range = (0, 0.1)
end

@testset "Makie recipes: change node color" begin
    fig, ax, p = viz(opf, color=:Length, color_range=(0, 0.2))

    leaf = get_node(opf, 5)
    leaf[:_cache_d9b4f7f3c3467a55ad26f362065777c471aee4c7][] = parse(Colorant, :red)

    @test_reference "reference_images/opf_color_attribute_observable_node.png" fig

    # Making the whole plot red:
    fig, ax, p = viz(opf, color=:red)
    # Update with a green leaf:
    leaf = get_node(opf, 5)
    leaf[:_cache_d9b4f7f3c3467a55ad26f362065777c471aee4c7][] = parse(Colorant, :green)

    @test_reference "reference_images/opf_color_attribute_observable_node_red_green.png" fig

    # Making the whole plot blue:
    p.color = :blue
    @test_reference "reference_images/opf_color_attribute_observable_node_blue.png" fig
end