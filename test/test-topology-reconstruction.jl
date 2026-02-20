@testset "topology reconstruction" begin
    tri = GeometryBasics.TriangleFace{Int}

    stem_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            0.5,
        ),
    )

    leaf_mesh = GeometryBasics.Mesh(
        [
            Point(0.0, -0.1, 0.0),
            Point(0.0, 0.1, 0.0),
            Point(1.0, 0.0, 0.0),
        ],
        [tri(1, 2, 3)],
    )

    ref_meshes = Dict(
        "Internode" => RefMesh("Stem", stem_mesh),
        "Leaf" => RefMesh("Leaf", leaf_mesh),
    )

    conv = default_amap_geometry_convention()
    @test conv.length_axis == :x
    @test any(a -> :XInsertionAngle in a.names, conv.angle_map)

    file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")

    mtg = read_mtg(file)
    set_geometry_from_attributes!(mtg, ref_meshes; convention=conv)

    internodes = Any[]
    leaves = Any[]

    traverse!(mtg) do node
        if symbol(node) == "Internode"
            push!(internodes, node)
        elseif symbol(node) == "Leaf"
            push!(leaves, node)
        end
    end

    @test length(internodes) == 2
    @test length(leaves) == 2
    @test all(n -> haskey(n, :geometry), internodes)
    @test all(n -> haskey(n, :geometry), leaves)

    p0 = SVector{3,Float64}(0.0, 0.0, 0.0)
    p1 = SVector{3,Float64}(1.0, 0.0, 0.0)

    base_1 = SVector{3,Float64}(internodes[1][:geometry].transformation(p0))
    top_1 = SVector{3,Float64}(internodes[1][:geometry].transformation(p1))
    base_2 = SVector{3,Float64}(internodes[2][:geometry].transformation(p0))

    # Successor internode starts at predecessor top.
    @test LinearAlgebra.norm(base_2 - top_1) < 1e-10

    leaf_1 = leaves[1]
    leaf_1_base = SVector{3,Float64}(leaf_1[:geometry].transformation(p0))

    # AMAP-like default insertion mode is BORDER: branch origin is offset from bearer top.
    @test LinearAlgebra.norm(leaf_1_base - top_1) > 1e-6

    mtg2 = read_mtg(file)
    reconstruct_geometry_from_attributes!(mtg2, ref_meshes; convention=conv)
    @test length(descendants(mtg2, :geometry; ignore_nothing=true, self=true)) == 4

    # CENTER insertion mode disables border offset.
    mtg3 = read_mtg(file)
    set_geometry_from_attributes!(mtg3, ref_meshes; convention=conv)

    first_leaf = nothing
    first_internode = nothing
    traverse!(mtg3) do node
        if symbol(node) == "Internode" && first_internode === nothing
            first_internode = node
        elseif symbol(node) == "Leaf" && first_leaf === nothing
            first_leaf = node
        end
    end

    first_leaf[:InsertionMode] = "CENTER"
    reconstruct_geometry_from_attributes!(mtg3, ref_meshes; convention=conv)

    center_leaf_base = SVector{3,Float64}(first_leaf[:geometry].transformation(p0))
    first_internode_top = SVector{3,Float64}(first_internode[:geometry].transformation(p1))
    @test LinearAlgebra.norm(center_leaf_base - first_internode_top) < 1e-10

    @testset "insertion mode WIDTH and HEIGHT" begin
        mode_file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")
        mode_mtg = read_mtg(mode_file)

        mode_internode = nothing
        mode_leaf = nothing
        traverse!(mode_mtg) do node
            if symbol(node) == "Internode" && mode_internode === nothing
                mode_internode = node
            elseif symbol(node) == "Leaf" && mode_leaf === nothing
                mode_leaf = node
            end
        end

        mode_internode[:TopWidth] = 0.12
        mode_internode[:TopHeight] = 0.04
        mode_leaf[:InsertionMode] = "WIDTH"

        reconstruct_geometry_from_attributes!(mode_mtg, ref_meshes; convention=conv)

        internode_top = SVector{3,Float64}(mode_internode[:geometry].transformation(p1))
        internode_base = SVector{3,Float64}(mode_internode[:geometry].transformation(p0))
        internode_y = SVector{3,Float64}(mode_internode[:geometry].transformation(SVector(0.0, 1.0, 0.0)))
        internode_z = SVector{3,Float64}(mode_internode[:geometry].transformation(SVector(0.0, 0.0, 1.0)))
        width_base = SVector{3,Float64}(mode_leaf[:geometry].transformation(p0))
        width_delta = width_base - internode_top

        width_axis = LinearAlgebra.normalize(internode_y - internode_base)
        height_axis = LinearAlgebra.normalize(internode_z - internode_base)

        @test LinearAlgebra.norm(width_delta) ≈ 0.06 atol = 1e-8
        @test abs(LinearAlgebra.dot(LinearAlgebra.normalize(width_delta), width_axis)) > 0.95
        @test abs(LinearAlgebra.dot(LinearAlgebra.normalize(width_delta), height_axis)) < 0.2

        mode_leaf[:InsertionMode] = "HEIGHT"
        reconstruct_geometry_from_attributes!(mode_mtg, ref_meshes; convention=conv)

        height_base = SVector{3,Float64}(mode_leaf[:geometry].transformation(p0))
        height_delta = height_base - internode_top

        @test LinearAlgebra.norm(height_delta) ≈ 0.02 atol = 1e-8
        @test abs(LinearAlgebra.dot(LinearAlgebra.normalize(height_delta), height_axis)) > 0.95
        @test abs(LinearAlgebra.dot(LinearAlgebra.normalize(height_delta), width_axis)) < 0.2
    end

    @testset "phyllotaxy fallback and verticil mode" begin
        ramif = Node(NodeMTG("/", "Plant", 1, 1))
        bearer = Node(ramif, NodeMTG("/", "Internode", 1, 2))
        leaf_a = Node(bearer, NodeMTG("+", "Leaf", 1, 2))
        leaf_b = Node(bearer, NodeMTG("+", "Leaf", 2, 2))

        bearer[:Length] = 0.3
        bearer[:Width] = 0.06
        bearer[:Thickness] = 0.04

        for leaf in (leaf_a, leaf_b)
            leaf[:Length] = 0.2
            leaf[:Width] = 0.1
            leaf[:Thickness] = 0.002
            leaf[:YInsertionAngle] = 55.0
            leaf[:Phyllotaxy] = 30.0
            leaf[:InsertionMode] = "CENTER"
        end

        reconstruct_geometry_from_attributes!(ramif, ref_meshes; convention=conv, verticil_mode=:none)

        y_none_a = LinearAlgebra.normalize(
            SVector{3,Float64}(leaf_a[:geometry].transformation(SVector(0.0, 1.0, 0.0))) -
            SVector{3,Float64}(leaf_a[:geometry].transformation(p0)),
        )
        y_none_b = LinearAlgebra.normalize(
            SVector{3,Float64}(leaf_b[:geometry].transformation(SVector(0.0, 1.0, 0.0))) -
            SVector{3,Float64}(leaf_b[:geometry].transformation(p0)),
        )
        @test LinearAlgebra.dot(y_none_a, y_none_b) > 0.999

        reconstruct_geometry_from_attributes!(ramif, ref_meshes; convention=conv, verticil_mode=:rotation360)

        y_rot_a = LinearAlgebra.normalize(
            SVector{3,Float64}(leaf_a[:geometry].transformation(SVector(0.0, 1.0, 0.0))) -
            SVector{3,Float64}(leaf_a[:geometry].transformation(p0)),
        )
        y_rot_b = LinearAlgebra.normalize(
            SVector{3,Float64}(leaf_b[:geometry].transformation(SVector(0.0, 1.0, 0.0))) -
            SVector{3,Float64}(leaf_b[:geometry].transformation(p0)),
        )
        @test LinearAlgebra.dot(y_rot_a, y_rot_b) < -0.9
    end

    # Reproducible docs fixture: check we reconstruct all organs and leaves are not parallel.
    demo_file = joinpath(@__DIR__, "files", "reconstruction_standard.mtg")
    demo = read_mtg(demo_file)
    set_geometry_from_attributes!(demo, ref_meshes; convention=conv)

    demo_internodes = Any[]
    demo_leaves = Any[]
    traverse!(demo) do node
        if symbol(node) == "Internode"
            push!(demo_internodes, node)
        elseif symbol(node) == "Leaf"
            push!(demo_leaves, node)
        end
    end

    @test length(descendants(demo, :geometry; ignore_nothing=true, self=true)) == 8
    @test length(demo_internodes) == 4
    @test length(demo_leaves) == 4

    cosines = Float64[]
    for i in 1:4
        ds = SVector{3,Float64}(demo_internodes[i][:geometry].transformation(p1)) -
             SVector{3,Float64}(demo_internodes[i][:geometry].transformation(p0))
        dl = SVector{3,Float64}(demo_leaves[i][:geometry].transformation(p1)) -
             SVector{3,Float64}(demo_leaves[i][:geometry].transformation(p0))
        push!(cosines, abs(LinearAlgebra.dot(ds, dl) / (LinearAlgebra.norm(ds) * LinearAlgebra.norm(dl))))
    end
    @test maximum(cosines) < 0.95
end
