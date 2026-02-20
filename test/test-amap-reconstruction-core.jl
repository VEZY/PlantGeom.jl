@testset "amap reconstruction core" begin
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
    amap = default_amap_reconstruction_options()

    p0 = SVector{3,Float64}(0.0, 0.0, 0.0)
    px = SVector{3,Float64}(1.0, 0.0, 0.0)
    py = SVector{3,Float64}(0.0, 1.0, 0.0)
    pz = SVector{3,Float64}(0.0, 0.0, 1.0)

    @testset "azimuth and elevation orientation override" begin
        mtg = Node(NodeMTG("/", "Plant", 1, 1))
        stem = Node(mtg, NodeMTG("/", "Internode", 1, 2))
        stem[:Length] = 1.0
        stem[:Width] = 0.1
        stem[:Thickness] = 0.1
        stem[:XInsertionAngle] = 20.0
        stem[:Azimuth] = 90.0
        stem[:Elevation] = 0.0

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        dir = LinearAlgebra.normalize(
            SVector{3,Float64}(stem[:geometry].transformation(px)) -
            SVector{3,Float64}(stem[:geometry].transformation(p0)),
        )
        @test dir[2] > 0.99
        @test abs(dir[1]) < 1e-3
    end

    @testset "deviation world axis rotation" begin
        mtg = Node(NodeMTG("/", "Plant", 1, 1))
        stem = Node(mtg, NodeMTG("/", "Internode", 1, 2))
        stem[:Length] = 1.0
        stem[:Width] = 0.1
        stem[:Thickness] = 0.1
        stem[:DeviationAngle] = 90.0

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        dir = LinearAlgebra.normalize(
            SVector{3,Float64}(stem[:geometry].transformation(px)) -
            SVector{3,Float64}(stem[:geometry].transformation(p0)),
        )
        @test dir[2] > 0.99
        @test abs(dir[1]) < 1e-3
    end

    @testset "orthotropy and stiffness angle precedence" begin
        mtg_ortho = Node(NodeMTG("/", "Plant", 1, 1))
        stem_ortho = Node(mtg_ortho, NodeMTG("/", "Internode", 1, 2))
        stem_ortho[:Length] = 1.0
        stem_ortho[:Width] = 0.1
        stem_ortho[:Thickness] = 0.1
        stem_ortho[:Orthotropy] = 30.0

        reconstruct_geometry_from_attributes!(
            mtg_ortho,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )
        dir_ortho = LinearAlgebra.normalize(
            SVector{3,Float64}(stem_ortho[:geometry].transformation(px)) -
            SVector{3,Float64}(stem_ortho[:geometry].transformation(p0)),
        )
        @test dir_ortho[3] > 0.0

        mtg_stiff = Node(NodeMTG("/", "Plant", 1, 1))
        stem_stiff = Node(mtg_stiff, NodeMTG("/", "Internode", 1, 2))
        stem_stiff[:Length] = 1.0
        stem_stiff[:Width] = 0.1
        stem_stiff[:Thickness] = 0.1
        stem_stiff[:Orthotropy] = 30.0
        stem_stiff[:StiffnessAngle] = -20.0

        reconstruct_geometry_from_attributes!(
            mtg_stiff,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )
        dir_stiff = LinearAlgebra.normalize(
            SVector{3,Float64}(stem_stiff[:geometry].transformation(px)) -
            SVector{3,Float64}(stem_stiff[:geometry].transformation(p0)),
        )
        @test dir_stiff[3] < 0.0
    end

    @testset "projection flags normal up and plagiotropy" begin
        mtg = Node(NodeMTG("/", "Plant", 1, 1))
        stem = Node(mtg, NodeMTG("/", "Internode", 1, 2))
        stem[:Length] = 1.0
        stem[:Width] = 0.1
        stem[:Thickness] = 0.1
        stem[:XEuler] = 180.0
        stem[:NormalUp] = true
        stem[:Plagiotropy] = true

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        normal_vec = SVector{3,Float64}(stem[:geometry].transformation(pz)) -
                     SVector{3,Float64}(stem[:geometry].transformation(p0))
        secondary_vec = SVector{3,Float64}(stem[:geometry].transformation(py)) -
                        SVector{3,Float64}(stem[:geometry].transformation(p0))
        @test normal_vec[3] >= -1e-8
        @test secondary_vec[3] >= -1e-8
    end

    @testset "orientation reset on successor axis" begin
        mtg_base = Node(NodeMTG("/", "Plant", 1, 1))
        i1 = Node(mtg_base, NodeMTG("/", "Internode", 1, 2))
        i2 = Node(i1, NodeMTG("<", "Internode", 2, 2))
        i1[:Length] = 0.4
        i1[:Width] = 0.08
        i1[:Thickness] = 0.08
        i1[:YInsertionAngle] = 45.0
        i2[:Length] = 0.3
        i2[:Width] = 0.07
        i2[:Thickness] = 0.07

        mtg_reset = deepcopy(mtg_base)
        internodes_reset = Any[]
        internodes_base = Any[]
        traverse!(mtg_reset) do node
            symbol(node) == "Internode" && push!(internodes_reset, node)
        end
        traverse!(mtg_base) do node
            symbol(node) == "Internode" && push!(internodes_base, node)
        end
        internodes_reset[2][:OrientationReset] = true

        reconstruct_geometry_from_attributes!(mtg_base, ref_meshes; convention=conv, root_align=true)
        reconstruct_geometry_from_attributes!(mtg_reset, ref_meshes; convention=conv, amap_options=amap, root_align=true)

        base_second = internodes_base[2]
        reset_second = internodes_reset[2]

        dir_base = LinearAlgebra.normalize(
            SVector{3,Float64}(base_second[:geometry].transformation(px)) -
            SVector{3,Float64}(base_second[:geometry].transformation(p0)),
        )
        dir_reset = LinearAlgebra.normalize(
            SVector{3,Float64}(reset_second[:geometry].transformation(px)) -
            SVector{3,Float64}(reset_second[:geometry].transformation(p0)),
        )

        @test dir_base[3] < 0.95
        @test dir_reset[3] > 0.99
    end

    @testset "Insertion alias support" begin
        file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")
        mtg = read_mtg(file)

        first_leaf = nothing
        first_internode = nothing
        traverse!(mtg) do node
            if symbol(node) == "Internode" && first_internode === nothing
                first_internode = node
            elseif symbol(node) == "Leaf" && first_leaf === nothing
                first_leaf = node
            end
        end

        first_leaf[:Insertion] = "CENTER"
        reconstruct_geometry_from_attributes!(mtg, ref_meshes; convention=conv, amap_options=amap)

        leaf_base = SVector{3,Float64}(first_leaf[:geometry].transformation(p0))
        internode_top = SVector{3,Float64}(first_internode[:geometry].transformation(px))
        @test LinearAlgebra.norm(leaf_base - internode_top) < 1e-10
    end

    @testset "order map behavior with branching order" begin
        mtg = Node(NodeMTG("/", "Plant", 1, 1))
        bearer = Node(mtg, NodeMTG("/", "Internode", 1, 2))
        leaf_a = Node(bearer, NodeMTG("+", "Leaf", 1, 2))
        leaf_b = Node(bearer, NodeMTG("+", "Leaf", 2, 2))

        bearer[:Length] = 0.3
        bearer[:Width] = 0.08
        bearer[:Thickness] = 0.08

        for leaf in (leaf_a, leaf_b)
            leaf[:Length] = 0.2
            leaf[:Width] = 0.1
            leaf[:Thickness] = 0.002
            leaf[:InsertionMode] = "CENTER"
        end

        amap_order = AmapReconstructionOptions(
            insertion_y_by_order=Dict(2 => 60.0),
            phyllotaxy_by_order=Dict(2 => 45.0),
            order_override_mode=:override,
        )

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap_order,
            root_align=false,
        )

        @test leaf_a[:branching_order] == 2
        @test leaf_b[:branching_order] == 2

        d_a = LinearAlgebra.normalize(
            SVector{3,Float64}(leaf_a[:geometry].transformation(px)) -
            SVector{3,Float64}(leaf_a[:geometry].transformation(p0)),
        )
        d_b = LinearAlgebra.normalize(
            SVector{3,Float64}(leaf_b[:geometry].transformation(px)) -
            SVector{3,Float64}(leaf_b[:geometry].transformation(p0)),
        )
        y_a = LinearAlgebra.normalize(
            SVector{3,Float64}(leaf_a[:geometry].transformation(py)) -
            SVector{3,Float64}(leaf_a[:geometry].transformation(p0)),
        )
        y_b = LinearAlgebra.normalize(
            SVector{3,Float64}(leaf_b[:geometry].transformation(py)) -
            SVector{3,Float64}(leaf_b[:geometry].transformation(p0)),
        )

        @test abs(d_a[3]) > 0.5
        @test abs(d_b[3]) > 0.5
        @test LinearAlgebra.dot(y_a, y_b) < -0.9
    end

    @testset "default amap_options matches explicit default options" begin
        file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")
        mtg_a = read_mtg(file)
        mtg_b = read_mtg(file)

        reconstruct_geometry_from_attributes!(mtg_a, ref_meshes; convention=conv)
        reconstruct_geometry_from_attributes!(mtg_b, ref_meshes; convention=conv, amap_options=amap)

        geoms_a = descendants(mtg_a, :geometry; ignore_nothing=true, self=true)
        geoms_b = descendants(mtg_b, :geometry; ignore_nothing=true, self=true)
        @test length(geoms_a) == length(geoms_b)

        for (ga, gb) in zip(geoms_a, geoms_b)
            ma = PlantGeom.transformation_matrix4(ga.transformation)
            mb = PlantGeom.transformation_matrix4(gb.transformation)
            @test maximum(abs.(ma .- mb)) < 1e-12
        end
    end
end
