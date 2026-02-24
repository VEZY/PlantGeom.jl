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
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
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
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
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
        mtg_ortho = Node(NodeMTG(:/, :Plant, 1, 1))
        stem_ortho = Node(mtg_ortho, NodeMTG(:/, :Internode, 1, 2))
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

        mtg_stiff = Node(NodeMTG(:/, :Plant, 1, 1))
        stem_stiff = Node(mtg_stiff, NodeMTG(:/, :Internode, 1, 2))
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

    @testset "stiffness propagation to component children" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        c1 = Node(stem, NodeMTG(:/, :Leaf, 1, 3))
        c2 = Node(stem, NodeMTG(:/, :Leaf, 2, 3))

        stem[:Length] = 40.0
        stem[:Width] = 0.15
        stem[:Thickness] = 0.15
        stem[:Stifness] = 5.0e4
        stem[:StifnessTapering] = 0.6

        for c in (c1, c2)
            c[:Length] = 0.25
            c[:Width] = 0.08
            c[:Thickness] = 0.01
        end

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        @test haskey(c1, :StiffnessAngle)
        @test haskey(c2, :StiffnessAngle)
        @test c2[:StiffnessAngle] < -1e-6

        mtg_up = deepcopy(mtg)
        comps_up = Any[]
        stem_up = nothing
        traverse!(mtg_up) do node
            if symbol(node) == :Internode && stem_up === nothing
                stem_up = node
            elseif symbol(node) == :Leaf
                push!(comps_up, node)
            end
        end
        stem_up[:Stifness] = -5.0e4
        stem_up[:StiffnessApply] = true

        reconstruct_geometry_from_attributes!(
            mtg_up,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )
        @test comps_up[2][:StiffnessAngle] > 1e-6

        mtg_off = deepcopy(mtg)
        comps_off = Any[]
        stem_off = nothing
        traverse!(mtg_off) do node
            if symbol(node) == :Internode && stem_off === nothing
                stem_off = node
            elseif symbol(node) == :Leaf
                push!(comps_off, node)
            end
        end
        stem_off[:StiffnessApply] = false
        for c in comps_off
            c[:StiffnessAngle] = 0.0
        end

        reconstruct_geometry_from_attributes!(
            mtg_off,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )
        @test comps_off[1][:StiffnessAngle] == 0.0
        @test comps_off[2][:StiffnessAngle] == 0.0
    end

    @testset "stiffness straightening dampens distal bending" begin
        function _build_straightening_case()
            mtg = Node(NodeMTG(:/, :Plant, 1, 1))
            stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
            stem[:Length] = 30.0
            stem[:Width] = 0.12
            stem[:Thickness] = 0.12
            stem[:Stifness] = 120.0
            stem[:StifnessTapering] = 0.5

            comps = Any[]
            for i in 1:8
                c = Node(stem, NodeMTG(:/, :Leaf, i, 3))
                c[:Length] = 0.2
                c[:Width] = 0.05
                c[:Thickness] = 0.01
                push!(comps, c)
            end
            return mtg, stem, comps
        end

        mtg_none, stem_none, comps_none = _build_straightening_case()
        mtg_str, stem_str, comps_str = _build_straightening_case()

        stem_none[:StiffnessApply] = true
        stem_str[:StiffnessApply] = true
        stem_str[:StiffnessStraightening] = 0.35

        reconstruct_geometry_from_attributes!(
            mtg_none,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )
        reconstruct_geometry_from_attributes!(
            mtg_str,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        distal_none = abs(comps_none[end][:StiffnessAngle])
        distal_str = abs(comps_str[end][:StiffnessAngle])
        @test distal_str < distal_none
    end

    @testset "broken attribute applies AMAP broken-segment rule" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        stem[:Length] = 20.0
        stem[:Width] = 0.12
        stem[:Thickness] = 0.12
        stem[:StiffnessApply] = false
        stem[:Broken] = 50.0

        comps = Any[]
        for i in 1:5
            c = Node(stem, NodeMTG(:/, :Leaf, i, 3))
            c[:Length] = 0.2
            c[:Width] = 0.05
            c[:Thickness] = 0.01
            push!(comps, c)
        end

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        @test comps[1][:StiffnessAngle] != -180.0
        @test comps[2][:StiffnessAngle] != -180.0
        @test comps[3][:StiffnessAngle] == -180.0
        @test comps[4][:StiffnessAngle] == -180.0
        @test comps[5][:StiffnessAngle] == -180.0
    end

    @testset "successor anchors on last component top (AMAP parity)" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        comp1 = Node(stem, NodeMTG(:/, :Leaf, 1, 3))
        comp2 = Node(stem, NodeMTG(:/, :Leaf, 2, 3))
        succ = Node(stem, NodeMTG(:<, :Internode, 2, 2))

        stem[:Length] = 0.8
        stem[:Width] = 0.12
        stem[:Thickness] = 0.12

        comp1[:Length] = 0.25
        comp1[:Width] = 0.08
        comp1[:Thickness] = 0.01
        comp1[:YInsertionAngle] = 15.0

        comp2[:Length] = 0.35
        comp2[:Width] = 0.08
        comp2[:Thickness] = 0.01
        comp2[:YInsertionAngle] = 55.0

        succ[:Length] = 0.30
        succ[:Width] = 0.10
        succ[:Thickness] = 0.10

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        succ_base = SVector{3,Float64}(succ[:geometry].transformation(p0))
        comp2_top = SVector{3,Float64}(comp2[:geometry].transformation(px))
        stem_top = SVector{3,Float64}(stem[:geometry].transformation(px))

        @test LinearAlgebra.norm(succ_base - comp2_top) < 1e-10
        @test LinearAlgebra.norm(comp2_top - stem_top) > 1e-4
    end

    @testset "projection flags normal up and plagiotropy" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
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

    @testset "projection remains stable when direction is near world up" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        stem[:Length] = 1.0
        stem[:Width] = 0.1
        stem[:Thickness] = 0.1
        stem[:Elevation] = 90.0
        stem[:NormalUp] = true
        stem[:Plagiotropy] = true

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        dir_vec = LinearAlgebra.normalize(
            SVector{3,Float64}(stem[:geometry].transformation(px)) -
            SVector{3,Float64}(stem[:geometry].transformation(p0)),
        )
        secondary_vec = LinearAlgebra.normalize(
            SVector{3,Float64}(stem[:geometry].transformation(py)) -
            SVector{3,Float64}(stem[:geometry].transformation(p0)),
        )
        normal_vec = LinearAlgebra.normalize(
            SVector{3,Float64}(stem[:geometry].transformation(pz)) -
            SVector{3,Float64}(stem[:geometry].transformation(p0)),
        )

        @test all(isfinite, dir_vec)
        @test all(isfinite, secondary_vec)
        @test all(isfinite, normal_vec)
        @test dir_vec[3] > 0.99
    end

    @testset "projection edge case remains stable for non-x length axis" begin
        conv_z = default_geometry_convention(length_axis=:z)
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        stem[:Length] = 1.0
        stem[:Width] = 0.2
        stem[:Thickness] = 0.1
        stem[:NormalUp] = true
        stem[:Plagiotropy] = true

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv_z,
            amap_options=amap,
            root_align=false,
        )

        dir_vec = LinearAlgebra.normalize(
            SVector{3,Float64}(stem[:geometry].transformation(pz)) -
            SVector{3,Float64}(stem[:geometry].transformation(p0)),
        )
        secondary_vec = LinearAlgebra.normalize(
            SVector{3,Float64}(stem[:geometry].transformation(px)) -
            SVector{3,Float64}(stem[:geometry].transformation(p0)),
        )
        normal_vec = LinearAlgebra.normalize(
            SVector{3,Float64}(stem[:geometry].transformation(py)) -
            SVector{3,Float64}(stem[:geometry].transformation(p0)),
        )

        @test all(isfinite, dir_vec)
        @test all(isfinite, secondary_vec)
        @test all(isfinite, normal_vec)
        @test abs(LinearAlgebra.dot(dir_vec, secondary_vec)) < 1e-6
        @test abs(LinearAlgebra.dot(dir_vec, normal_vec)) < 1e-6
        @test abs(LinearAlgebra.dot(secondary_vec, normal_vec)) < 1e-6
    end

    @testset "orientation reset on successor axis" begin
        mtg_base = Node(NodeMTG(:/, :Plant, 1, 1))
        i1 = Node(mtg_base, NodeMTG(:/, :Internode, 1, 2))
        i2 = Node(i1, NodeMTG(:<, :Internode, 2, 2))
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
            symbol(node) == :Internode && push!(internodes_reset, node)
        end
        traverse!(mtg_base) do node
            symbol(node) == :Internode && push!(internodes_base, node)
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
            if symbol(node) == :Internode && first_internode === nothing
                first_internode = node
            elseif symbol(node) == :Leaf && first_leaf === nothing
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
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        bearer = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        leaf_a = Node(bearer, NodeMTG(:+, :Leaf, 1, 2))
        leaf_b = Node(bearer, NodeMTG(:+, :Leaf, 2, 2))

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

    @testset "endpoint coordinates override orientation and length" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        stem[:Length] = 0.4
        stem[:Width] = 0.15
        stem[:Thickness] = 0.12
        stem[:XX] = 1.0
        stem[:YY] = 2.0
        stem[:ZZ] = 3.0
        stem[:EndX] = 1.0
        stem[:EndY] = 4.0
        stem[:EndZ] = 3.0
        # Should be ignored when End* coordinates are valid.
        stem[:Azimuth] = 180.0
        stem[:YInsertionAngle] = 45.0

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        base = SVector{3,Float64}(stem[:geometry].transformation(p0))
        top = SVector{3,Float64}(stem[:geometry].transformation(px))
        dir = LinearAlgebra.normalize(top - base)

        @test LinearAlgebra.norm(base - SVector{3,Float64}(1.0, 2.0, 3.0)) < 1e-10
        @test LinearAlgebra.norm(top - SVector{3,Float64}(1.0, 4.0, 3.0)) < 1e-10
        @test abs(LinearAlgebra.norm(top - base) - 2.0) < 1e-10
        @test dir[2] > 0.999
    end

    @testset "endpoint coordinates work with topology start and successor chaining" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        i1 = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        i2 = Node(i1, NodeMTG(:<, :Internode, 2, 2))
        i3 = Node(i2, NodeMTG(:<, :Internode, 3, 2))

        i1[:Length] = 1.0
        i1[:Width] = 0.1
        i1[:Thickness] = 0.1

        i2[:Length] = 0.2
        i2[:Width] = 0.08
        i2[:Thickness] = 0.08
        i2[:EndX] = 2.0
        i2[:EndY] = 1.0
        i2[:EndZ] = 0.0

        i3[:Length] = 0.5
        i3[:Width] = 0.07
        i3[:Thickness] = 0.07

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        i1_top = SVector{3,Float64}(i1[:geometry].transformation(px))
        i2_base = SVector{3,Float64}(i2[:geometry].transformation(p0))
        i2_top = SVector{3,Float64}(i2[:geometry].transformation(px))
        i3_base = SVector{3,Float64}(i3[:geometry].transformation(p0))

        @test LinearAlgebra.norm(i2_base - i1_top) < 1e-10
        @test LinearAlgebra.norm(i2_top - SVector{3,Float64}(2.0, 1.0, 0.0)) < 1e-10
        @test LinearAlgebra.norm(i3_base - i2_top) < 1e-10
    end

    @testset "incomplete endpoint coordinates are ignored" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        stem[:Length] = 1.0
        stem[:Width] = 0.1
        stem[:Thickness] = 0.1
        stem[:YInsertionAngle] = 90.0
        stem[:EndX] = 2.0
        # EndY/EndZ intentionally missing.

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        base = SVector{3,Float64}(stem[:geometry].transformation(p0))
        top = SVector{3,Float64}(stem[:geometry].transformation(px))
        dir = LinearAlgebra.normalize(top - base)

        @test abs(dir[3]) > 0.99
        @test abs(dir[1]) < 1e-6
    end

    @testset "explicit_start_end_required skips geometry when explicit start has no complete end" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        stem[:Length] = 1.0
        stem[:Width] = 0.1
        stem[:Thickness] = 0.1
        stem[:XX] = 0.0
        stem[:YY] = 0.0
        stem[:ZZ] = 0.0

        strict_opts = AmapReconstructionOptions(coordinate_delegate_mode=:explicit_start_end_required)
        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=strict_opts,
            root_align=false,
        )

        @test stem[:geometry] === nothing
    end

    @testset "explicit_coordinate_mode alias maps to coordinate_delegate_mode" begin
        opts_alias = AmapReconstructionOptions(explicit_coordinate_mode=:explicit_rewire_previous)
        @test opts_alias.coordinate_delegate_mode == :explicit_rewire_previous

        opts_same = AmapReconstructionOptions(
            coordinate_delegate_mode=:topology_default,
            explicit_coordinate_mode=:topology_default,
        )
        @test opts_same.coordinate_delegate_mode == :topology_default

        @test_throws ErrorException AmapReconstructionOptions(
            coordinate_delegate_mode=:topology_default,
            explicit_coordinate_mode=:explicit_rewire_previous,
        )
    end

    @testset "explicit_rewire_previous updates predecessor segment from explicit node coordinates" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        p1 = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        p2 = Node(p1, NodeMTG(:<, :Internode, 2, 2))

        for n in (p1, p2)
            n[:Length] = 0.5
            n[:Width] = 0.1
            n[:Thickness] = 0.1
        end
        p1[:XX] = 0.0
        p1[:YY] = 0.0
        p1[:ZZ] = 0.0
        p2[:XX] = 1.0
        p2[:YY] = 0.2
        p2[:ZZ] = 0.0

        d2_opts = AmapReconstructionOptions(coordinate_delegate_mode=:explicit_rewire_previous)
        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=d2_opts,
            root_align=false,
        )

        p1_base = SVector{3,Float64}(p1[:geometry].transformation(p0))
        p1_top = SVector{3,Float64}(p1[:geometry].transformation(px))
        p2_base = SVector{3,Float64}(p2[:geometry].transformation(p0))
        p2_top = SVector{3,Float64}(p2[:geometry].transformation(px))

        @test maximum(abs.(p1_base .- SVector(0.0, 0.0, 0.0))) < 1e-8
        @test maximum(abs.(p1_top .- SVector(1.0, 0.2, 0.0))) < 1e-6
        @test maximum(abs.(p2_base .- SVector(1.0, 0.2, 0.0))) < 1e-8
        @test norm(p2_top - p2_base) < 1e-8
    end

    @testset "allometry interpolates missing width and height on axis" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        i1 = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        i2 = Node(i1, NodeMTG(:<, :Internode, 2, 2))
        i3 = Node(i2, NodeMTG(:<, :Internode, 3, 2))

        for n in (i1, i2, i3)
            n[:Length] = 0.2
        end
        i1[:Width] = 0.2
        i1[:Thickness] = 0.2
        i3[:Width] = 0.6
        i3[:Thickness] = 0.4

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        @test isapprox(i2[:Width], 0.4; atol=1e-8)
        @test isapprox(i2[:Thickness], 0.3; atol=1e-8)
    end

    @testset "allometry propagation to components split vs copy semantics" begin
        mtg_split = Node(NodeMTG(:/, :Plant, 1, 1))
        ctrl_split = Node(mtg_split, NodeMTG(:/, :Internode, 1, 2))
        c1 = Node(ctrl_split, NodeMTG(:/, :Leaf, 1, 3))
        c2 = Node(c1, NodeMTG(:<, :Leaf, 2, 3))

        ctrl_split[:Length] = 0.8
        ctrl_split[:Width] = 0.2
        ctrl_split[:Thickness] = 0.1

        mtg_copy = Node(NodeMTG(:/, :Plant, 1, 1))
        ctrl_copy = Node(mtg_copy, NodeMTG(:/, :Internode, 1, 2))
        c3 = Node(ctrl_copy, NodeMTG(:/, :Leaf, 1, 3))
        c4 = Node(ctrl_copy, NodeMTG(:/, :Leaf, 2, 3))

        ctrl_copy[:Length] = 0.8
        ctrl_copy[:Width] = 0.2
        ctrl_copy[:Thickness] = 0.1

        reconstruct_geometry_from_attributes!(
            mtg_split,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )
        reconstruct_geometry_from_attributes!(
            mtg_copy,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        @test isapprox(c1[:Length], 0.4; atol=1e-8)
        @test isapprox(c2[:Length], 0.4; atol=1e-8)
        @test isapprox(c3[:Length], 0.8; atol=1e-8)
        @test isapprox(c4[:Length], 0.8; atol=1e-8)
        @test isapprox(c1[:Width], 0.2; atol=1e-8)
        @test isapprox(c2[:Thickness], 0.1; atol=1e-8)
    end

    @testset "allometry accumulates terminal components to complex when missing" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        complex = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        comp1 = Node(complex, NodeMTG(:/, :Leaf, 1, 3))
        comp2 = Node(comp1, NodeMTG(:<, :Leaf, 2, 3))

        comp1[:Length] = 0.3
        comp1[:Width] = 0.1
        comp1[:Thickness] = 0.08
        comp2[:Length] = 0.5
        comp2[:Width] = 0.25
        comp2[:Thickness] = 0.12

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        @test isapprox(complex[:Length], 0.8; atol=1e-8)
        @test isapprox(complex[:Width], 0.25; atol=1e-8)
        @test isapprox(complex[:Thickness], 0.25; atol=1e-8)
    end

    @testset "allometry smooths predecessor top dimensions" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        i1 = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        i2 = Node(i1, NodeMTG(:<, :Internode, 2, 2))

        i1[:Length] = 0.2
        i1[:Width] = 0.1
        i1[:Thickness] = 0.1
        i2[:Length] = 0.2
        i2[:Width] = 0.3
        i2[:Thickness] = 0.25

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        @test isapprox(i1[:TopWidth], 0.3; atol=1e-8)
        @test isapprox(i1[:TopHeight], 0.25; atol=1e-8)
    end

    @testset "geometrical cone constraint clamps successor direction" begin
        mtg_free = Node(NodeMTG(:/, :Plant, 1, 1))
        f1 = Node(mtg_free, NodeMTG(:/, :Internode, 1, 2))
        f2 = Node(f1, NodeMTG(:<, :Internode, 2, 2))
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        i1 = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        i2 = Node(i1, NodeMTG(:<, :Internode, 2, 2))

        for n in (f1, f2, i1, i2)
            n[:Length] = 1.0
            n[:Width] = 0.1
            n[:Thickness] = 0.1
        end
        f2[:YInsertionAngle] = -70.0
        i2[:YInsertionAngle] = -70.0

        constraint = Dict{Symbol,Any}(:type => :cone, :primary_angle => 20.0)
        i1[:GeometricalConstraint] = constraint
        i2[:GeometricalConstraint] = constraint

        reconstruct_geometry_from_attributes!(
            mtg_free,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        d_axis_free = LinearAlgebra.normalize(
            SVector{3,Float64}(f1[:geometry].transformation(px)) -
            SVector{3,Float64}(f1[:geometry].transformation(p0)),
        )
        d2_free = LinearAlgebra.normalize(
            SVector{3,Float64}(f2[:geometry].transformation(px)) -
            SVector{3,Float64}(f2[:geometry].transformation(p0)),
        )
        angle_free = rad2deg(acos(clamp(dot(d_axis_free, d2_free), -1.0, 1.0)))

        d_axis = LinearAlgebra.normalize(
            SVector{3,Float64}(i1[:geometry].transformation(px)) -
            SVector{3,Float64}(i1[:geometry].transformation(p0)),
        )
        d2 = LinearAlgebra.normalize(
            SVector{3,Float64}(i2[:geometry].transformation(px)) -
            SVector{3,Float64}(i2[:geometry].transformation(p0)),
        )
        angle = rad2deg(acos(clamp(dot(d_axis, d2), -1.0, 1.0)))
        @test angle < angle_free - 1.0
    end

    @testset "geometrical cylinder constraint clamps successor tip radius" begin
        mtg_free = Node(NodeMTG(:/, :Plant, 1, 1))
        f1 = Node(mtg_free, NodeMTG(:/, :Internode, 1, 2))
        f2 = Node(f1, NodeMTG(:<, :Internode, 2, 2))
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        i1 = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        i2 = Node(i1, NodeMTG(:<, :Internode, 2, 2))

        for n in (f1, f2, i1, i2)
            n[:Length] = 1.0
            n[:Width] = 0.1
            n[:Thickness] = 0.1
        end
        f2[:YInsertionAngle] = -80.0
        i2[:YInsertionAngle] = -80.0

        constraint = Dict{Symbol,Any}(:type => :cylinder, :radius => 0.2)
        i1[:GeometricalConstraint] = constraint
        i2[:GeometricalConstraint] = constraint

        reconstruct_geometry_from_attributes!(
            mtg_free,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=amap,
            root_align=false,
        )

        p_base_free = SVector{3,Float64}(f1[:geometry].transformation(p0))
        p_axis_free = SVector{3,Float64}(f1[:geometry].transformation(px))
        axis_free = LinearAlgebra.normalize(p_axis_free - p_base_free)
        p_tip2_free = SVector{3,Float64}(f2[:geometry].transformation(px))
        q_free = p_tip2_free - p_base_free
        radial_free = q_free - dot(q_free, axis_free) * axis_free

        p_base = SVector{3,Float64}(i1[:geometry].transformation(p0))
        p_axis = SVector{3,Float64}(i1[:geometry].transformation(px))
        axis = LinearAlgebra.normalize(p_axis - p_base)

        p_tip2 = SVector{3,Float64}(i2[:geometry].transformation(px))
        q = p_tip2 - p_base
        radial = q - dot(q, axis) * axis
        @test norm(radial) < norm(radial_free) - 1e-3
    end

    @testset "plane constraint projects direction into plane when base is out" begin
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))

        stem[:Length] = 1.0
        stem[:Width] = 0.1
        stem[:Thickness] = 0.1
        stem[:XX] = 0.0
        stem[:YY] = 0.0
        stem[:ZZ] = 0.5
        stem[:YInsertionAngle] = -70.0
        stem[:GeometricalConstraint] = Dict{Symbol,Any}(
            :type => :plane,
            :normal => (0.0, 0.0, 1.0),
            :d => 0.0,
        )

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
        @test abs(dir[3]) <= 1e-6
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
