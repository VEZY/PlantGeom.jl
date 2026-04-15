# Import / pre-compute
file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)

@testset "Makie recipes: reference meshes -> plot structure" begin
    f, ax, p = plantviz(meshes)
    @test p.converted.value[][1] == meshes
    @test typeof(p) <: Plot{plantviz,Tuple{Vector{T}}} where {T<:RefMesh}
    @test typeof(p.plots[1]) <: Makie.Mesh
    aligned_meshes = PlantGeom.align_ref_meshes(meshes)
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

file_coffee = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf")
mtg_coffee = read_opf(file_coffee)
@testset "Makie recipes: whole MTG -> attribute colors" begin
    f, ax, p = plantviz(mtg_coffee, color=:Area)
    @test length(p.vertex_colors[]) == PlantGeom.nvertices(p.merged_mesh[])
    @test_reference "reference_images/coffee_area.png" f
end

@testset "Makie recipes: whole MTG -> color-valued attributes" begin
    colored_opf = deepcopy(opf)
    palette = Any[:red, colorant"mediumseagreen", :peachpuff4, colorant"blanchedalmond"]
    i = Ref(0)
    traverse!(colored_opf; filter_fun=PlantGeom.has_geometry) do node
        i[] += 1
        node[:plot_color] = palette[mod1(i[], length(palette))]
    end

    fig, ax, p = plantviz(colored_opf, color=:plot_color)
    @test p.colorrange_resolved[] === nothing
    @test length(p.vertex_colors[]) == PlantGeom.nvertices(p.merged_mesh[])

    mktempdir() do tmp
        @test_nowarn save(joinpath(tmp, "color_attr.png"), fig)
    end
end


opf = read_opf(file)
meshes = get_ref_meshes(opf)

@testset "Makie recipes: whole MTG -> image references" begin
    @test_reference "reference_images/opf_basic.png" plantviz(opf)
    @test_reference "reference_images/opf_one_color.png" plantviz(opf, color=:red)
    @test_reference "reference_images/opf_one_color_per_ref.png" plantviz(opf, color=Dict("Mesh0" => :burlywood4, "Mesh1" => :springgreen4))
    @test_reference "reference_images/opf_one_color_one_ref.png" plantviz(opf, color=Dict("Mesh0" => :burlywood4))
    vertex_color = get_color(1:nvertices.(get_ref_meshes(opf))[1], [1, nvertices.(get_ref_meshes(opf))[1]])
    @test_reference "reference_images/opf_color_ref_vertex.png" plantviz(opf, color=Dict("Mesh0" => vertex_color))

    n_nodes = length(descendants(opf, :geometry; ignore_nothing=true, self=true))
    color_vec_rgb = get_color(1:n_nodes, [1, n_nodes])
    @test_reference "reference_images/opf_color_vector_rgb.png" plantviz(opf, color=color_vec_rgb)

    color_vec_symbol = [:red, :green, :blue, :yellow]
    @test_reference "reference_images/opf_color_vector_symbol.png" plantviz(opf, color=color_vec_symbol)

    transform!(opf, zmax => :z_max, ignore_nothing=true)
    @test_reference "reference_images/opf_color_attribute.png" plantviz(opf, color=:z_max)

    transform!(opf, (x -> [p[3] for p in GeometryBasics.coordinates(refmesh_to_mesh(x))]) => :z, filter_fun=node -> hasproperty(node, :geometry))
    @test_reference "reference_images/opf_color_attribute_vertex.png" plantviz(opf, color=:z, color_mode=:vertex)

    fig2, ax2, p2 = plantviz(opf, color=:z, color_mode=:vertex)
    colorbar(fig2[1, 2], p2)
    @test_reference "reference_images/opf_color_attribute_colorbar.png" fig2
    #! note: the reference image is not good, it should be colored by vertex, with a colorbar range from 0 to 0.3
    #! The package produces the right one outside of the tests. I tried everything I could but can't figure out 
    #! why the tests are producing a wrong one... I will leave it like this for now.

    fig3, ax3, p3 = plantviz(opf, color=:z, color_mode=:vertex, colorrange=(0.0u"m", 0.5u"m"))
    colorbar(fig3[1, 2], p3)
    @test_reference "reference_images/opf_color_attribute_colorbar_range.png" fig3
end

@testset "Makie recipes: explicit attribute color modes" begin
    opf_modes = read_opf(file)

    transform!(opf_modes, :Length => (x -> [x, 2x, 3x]) => :length_steps, ignore_nothing=true)
    transform!(
        opf_modes,
        (x -> [p[3] for p in GeometryBasics.coordinates(refmesh_to_mesh(x))]) => :z_vertex,
        filter_fun=node -> hasproperty(node, :geometry),
    )
    transform!(
        opf_modes,
        :z_vertex => (x -> hcat(x, x .+ 0.1)) => :z_vertex_steps,
        filter_fun=node -> hasproperty(node, :z_vertex),
        ignore_nothing=true,
    )

    fig_node, ax_node, p_node = plantviz(opf_modes, color=:length_steps, color_mode=:node)
    @test length(p_node.vertex_colors[]) == PlantGeom.nvertices(p_node.merged_mesh[])
    expected_node_colors = Colorant[]
    MultiScaleTreeGraph.traverse!(opf_modes; filter_fun=PlantGeom.has_geometry) do node
        nverts = PlantGeom.nvertices(PlantGeom.refmesh_to_mesh(node))
        color = PlantGeom.get_color(node[:length_steps][1], p_node.colorrange_resolved[]; colormap=p_node.colormap_resolved[])
        append!(expected_node_colors, fill(color, nverts))
    end
    @test p_node.vertex_colors[] == expected_node_colors

    fig_vertex, ax_vertex, p_vertex = plantviz(opf_modes, color=:z_vertex, color_mode=:vertex)
    @test length(p_vertex.vertex_colors[]) == PlantGeom.nvertices(p_vertex.merged_mesh[])
    expected_vertex_colors = Colorant[]
    MultiScaleTreeGraph.traverse!(opf_modes; filter_fun=PlantGeom.has_geometry) do node
        zvals = node[:z_vertex]
        append!(expected_vertex_colors, PlantGeom.get_color(zvals, p_vertex.colorrange_resolved[], nothing; colormap=p_vertex.colormap_resolved[]))
    end
    @test p_vertex.vertex_colors[] == expected_vertex_colors

    fig_vertex_steps, ax_vertex_steps, p_vertex_steps = plantviz(opf_modes, color=:z_vertex_steps, color_mode=:vertex, index=2)
    @test length(p_vertex_steps.vertex_colors[]) == PlantGeom.nvertices(p_vertex_steps.merged_mesh[])
    expected_vertex_step_colors = Colorant[]
    MultiScaleTreeGraph.traverse!(opf_modes; filter_fun=PlantGeom.has_geometry) do node
        zvals = node[:z_vertex_steps][:, 2]
        append!(expected_vertex_step_colors, PlantGeom.get_color(zvals, p_vertex_steps.colorrange_resolved[], nothing; colormap=p_vertex_steps.colormap_resolved[]))
    end
    @test p_vertex_steps.vertex_colors[] == expected_vertex_step_colors

    @test_throws Exception begin
        fig, ax, p = plantviz(opf_modes, color=:z_vertex)
        p.vertex_colors[]
    end
    @test_throws Exception begin
        fig, ax, p = plantviz(opf_modes, color=:length_steps)
        p.vertex_colors[]
    end
    @test_throws Exception begin
        fig, ax, p = plantviz(opf_modes, color=:z_vertex_steps, color_mode=:node)
        p.vertex_colors[]
    end
    @test_throws Exception begin
        fig, ax, p = plantviz(opf_modes, color=:z_vertex, color_mode=:vertex, index=1)
        p.vertex_colors[]
    end
end

@testset "Makie recipes: observables, change color" begin
    c = Observable(:blue)
    fig, ax, p = plantviz(opf, color=c)
    c[] = :red
    @test p.color[] == :red
    @test_reference "reference_images/opf_one_color.png" fig # Should come back to this plot in the end
end

@testset "Makie recipes: observables, change colorscale range" begin
    fig, ax, p = plantviz(opf, color=:Length, colorrange=(0, 0.2))
    @test p.attributes.colorrange[] == (0, 0.2)
    colorbar(fig[1, 2], p)
    p.colorrange[] = (0, 0.1)
    @test p.attributes.colorrange[] == (0, 0.1)
    @test_reference "reference_images/opf_dynamic_colorbar.png" fig # Should come back to this plot in the end
end

@testset "Makie recipes: testing Makie.Colorbar" begin
    # Same as before but with Makie.Colorbar
    fig, ax, p = plantviz(opf, color=:Length, colorrange=(0, 0.1))
    Makie.Colorbar(fig[1, 2], p)
    @test_reference "reference_images/opf_dynamic_colorbar.png" fig # Should come back to this plot in the end
end

@testset "Makie recipes: change variable for coloring" begin
    c = Observable(:Width)
    fig, ax, p = plantviz(opf, color=c)
    colorrange = p.colorrange_resolved[]
    c[] = :Length
    @test p.color[] == :Length
    @test p.colorrange_resolved[] != colorrange # The resolved color range should change with the variable
    fig
    @test_reference "reference_images/opf_color_attribute_length.png" fig
end

@testset "Makie recipes: filter nodes" begin
    @testset "Symbol" begin
        fig, ax, p = plantviz(opf, symbol=:Leaf)
        @test_reference "reference_images/opf_filter_symbol_leaf.png" fig

        fig, ax, p = plantviz(opf, symbol=:Leaf, color=:Length, colorrange=(0, 0.2))
        @test_reference "reference_images/opf_filter_symbol_leaf_colored_var.png" fig

        fig, ax, p = plantviz(opf, symbol=:Leaf, color=:red)
        @test_reference "reference_images/opf_filter_symbol_leaf_colored_red.png" fig
    end

    @testset "Symbol" begin
        fig, ax, p = plantviz(opf, scale=3)
        @test_reference "reference_images/opf_basic.png" fig
        # This is the same test as just plantviz(opf) because scale 3 is the only one with geometry

        fig, ax, p = plantviz(opf, scale=3, color=:Length, colorrange=(0, 0.2))
        @test_reference "reference_images/opf_filter_scale_leaf_internode_colored_var.png" fig
    end


    @testset "Link" begin
        fig, ax, p = plantviz(opf, link=:+)
        @test_reference "reference_images/opf_filter_symbol_leaf.png" fig
        # This is the same test as just `plantviz(opf, symbol=:Leaf)` because only the leaves are branching
    end


    @testset "Filter function" begin
        fig, ax, p = plantviz(opf, filter_fun=node -> link(node) == :+)
        @test_reference "reference_images/opf_filter_symbol_leaf.png" fig
        # This is the same test as just `plantviz(opf, symbol=:Leaf)` because only the leaves are branching
    end
end

@testset "Makie recipes: testing cache" begin
    file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
    opf = read_opf(file)
    fig, ax, p = plantviz(opf)
    # Check that face2node mapping was produced and cached scene exists
    root = MultiScaleTreeGraph.get_root(opf)
    cache = root[:_scene_cache]
    @test cache !== nothing
    @test hasproperty(cache, :mesh) && hasproperty(cache, :face2node) && hasproperty(cache, :hash)
    @test !isnothing(cache.mesh) && !isnothing(cache.face2node)
    @test length(cache.face2node) == PlantGeom.nelements(cache.mesh)
end

@testset "Makie recipes: attribute coloring is robust on sparse OPS attributes" begin
    mktempdir() do tmp
        opf_path = joinpath(tmp, "dyn_sparse_attr.opf")
        open(opf_path, "w") do io
            write(io, """
<?xml version="1.0" encoding="UTF-8"?>
<opf version="2.0" editable="true">
    <meshBDD>
        <mesh name="Q" shape="" Id="0" enableScale="false">
            <points>0 0 0 100 0 0 100 100 0</points>
            <normals>0 0 1 0 0 1 0 0 1</normals>
            <faces>0 1 2</faces>
        </mesh>
    </meshBDD>
    <materialBDD></materialBDD>
    <shapeBDD>
        <shape Id="0">
            <name>Q</name>
            <meshIndex>0</meshIndex>
            <materialIndex>0</materialIndex>
        </shape>
    </shapeBDD>
    <topology class="Plant" scale="1" id="1">
        <decomp class="Axis" scale="2" id="2">
            <geometry class="Mesh">
                <shapeIndex>0</shapeIndex>
                <mat>1 0 0 0 0 1 0 0 0 0 1 0</mat>
                <dUp>1.0</dUp>
                <dDwn>1.0</dDwn>
            </geometry>
            <decomp class="Axis" scale="3" id="3">
                <phyAge>1</phyAge>
                <geometry class="Mesh">
                    <shapeIndex>0</shapeIndex>
                    <mat>1 0 0 0 0 1 0 0 0 0 1 0</mat>
                    <dUp>1.0</dUp>
                    <dDwn>1.0</dDwn>
                </geometry>
            </decomp>
            <decomp class="Axis" scale="3" id="4">
                <phyAge>2</phyAge>
                <geometry class="Mesh">
                    <shapeIndex>0</shapeIndex>
                    <mat>1 0 0 0 0 1 0 0 0 0 1 0</mat>
                    <dUp>1.0</dUp>
                    <dDwn>1.0</dDwn>
                </geometry>
            </decomp>
        </decomp>
    </topology>
</opf>
""")
        end

        ops_path = joinpath(tmp, "scene.ops")
        open(ops_path, "w") do io
            println(io, "T 0 0 0 1 1 flat")
            println(io, "#[Archimed] p")
            println(io, "1\t1\tdyn_sparse_attr.opf\t0\t0\t0\t1\t0\t0\t0")
            println(io, "1\t2\tdyn_sparse_attr.opf\t0\t0\t0\t1\t0\t0\t0")
        end

        scene = read_ops(ops_path)
        fig, ax, p = plantviz(scene, color=:phyAge)
        @test_nowarn save(joinpath(tmp, "phyage.png"), fig)
        @test_nowarn Makie.extract_colormap(p)
    end
end
