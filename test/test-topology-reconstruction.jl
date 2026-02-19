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
