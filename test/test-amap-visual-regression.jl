@testset "amap visual regression" begin
    tri = GeometryBasics.TriangleFace{Int}
    conv = default_amap_geometry_convention()
    color_map = Dict("Stem" => RGB(0.58, 0.44, 0.30), "Leaf" => RGB(0.14, 0.52, 0.22))

    function _example_ref_meshes()
        stem_mesh = GeometryBasics.mesh(
            GeometryBasics.Cylinder(Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), 0.5),
        )
        leaf_mesh = GeometryBasics.Mesh(
            [
                Point(0.0, -0.06, -0.015),
                Point(0.0, 0.06, 0.025),
                Point(0.25, 0.0, 0.035),
                Point(1.0, 0.0, 0.0),
                Point(0.6, -0.2, -0.04),
                Point(0.6, 0.2, 0.08),
            ],
            tri[
                tri(1, 2, 3),
                tri(3, 5, 4),
                tri(3, 6, 4),
            ],
        )

        return Dict(
            "Internode" => RefMesh("Stem", stem_mesh, RGB(0.58, 0.44, 0.30)),
            "Leaf" => RefMesh("Leaf", leaf_mesh, RGB(0.16, 0.55, 0.22)),
        )
    end

    function _example_ref_meshes_verticil()
        stem_mesh = GeometryBasics.mesh(
            GeometryBasics.Cylinder(Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), 0.5),
        )
        leaf_mesh = GeometryBasics.Mesh(
            [
                Point(0.0, 0.12, 0.0),
                Point(0.0, 0.22, 0.05),
                Point(0.30, 0.18, 0.03),
                Point(1.00, 0.24, 0.02),
                Point(0.62, 0.32, 0.09),
                Point(0.55, 0.08, -0.05),
            ],
            tri[
                tri(1, 2, 3),
                tri(3, 5, 4),
                tri(3, 4, 6),
            ],
        )

        return Dict(
            "Internode" => RefMesh("Stem", stem_mesh, RGB(0.58, 0.44, 0.30)),
            "Leaf" => RefMesh("Leaf", leaf_mesh, RGB(0.16, 0.55, 0.22)),
        )
    end

    ref_meshes = _example_ref_meshes()
    ref_meshes_verticil = _example_ref_meshes_verticil()

    function _base_bearer!(node)
        node[:Length] = 0.22
        node[:Width] = 0.08
        node[:Thickness] = 0.045
        node[:TopWidth] = 0.10
        node[:TopHeight] = 0.045
        return node
    end

    function _new_leaf(parent, idx)
        leaf = Node(parent, NodeMTG(:+, :Leaf, idx, 2))
        leaf[:Length] = 0.24
        leaf[:Width] = 0.12
        leaf[:Thickness] = 0.002
        leaf[:Offset] = 0.18
        leaf[:BorderInsertionOffset] = 0.02
        return leaf
    end

    function insertion_mode_scene(mode::String)
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        bearer = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        _base_bearer!(bearer)
        bearer[:Length] = 0.10
        bearer[:Width] = 0.16
        bearer[:Thickness] = 0.14
        bearer[:TopWidth] = 0.18
        bearer[:TopHeight] = 0.16

        leaf = _new_leaf(bearer, 1)
        leaf[:Length] = 0.18
        leaf[:Offset] = 0.08
        leaf[:BorderInsertionOffset] = missing
        leaf[:InsertionMode] = mode
        leaf[:XInsertionAngle] = 35.0
        leaf[:YInsertionAngle] = 42.0

        set_geometry_from_attributes!(mtg, ref_meshes; convention=conv)
        return mtg
    end

    function verticil_mode_scene(mode::Symbol)
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        bearer = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        _base_bearer!(bearer)
        bearer[:Length] = 0.14
        bearer[:Width] = 0.06
        bearer[:Thickness] = 0.04
        bearer[:TopWidth] = 0.08
        bearer[:TopHeight] = 0.04

        for leaf_idx in 1:6
            leaf = _new_leaf(bearer, leaf_idx)
            leaf[:Length] = 0.15
            leaf[:Width] = 0.085
            leaf[:Offset] = 0.85 * bearer[:Length]
            leaf[:InsertionMode] = "CENTER"
            leaf[:YInsertionAngle] = 42.0
            leaf[:Phyllotaxy] = 0.0
        end

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes_verticil;
            convention=conv,
            verticil_mode=mode,
        )
        return mtg
    end

    function stiffness_scene(mode::Symbol)
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        axis = Node(mtg, NodeMTG(:/, :AxisNode, 1, 2))

        for i in 1:4
            axis[:Length] = 20.0
            axis[:Width] = 0.1
            axis[:Thickness] = 0.1
            axis[:Stifness] = 800.0
            axis[:StifnessTapering] = 0.5
            axis[:StiffnessApply] = mode == :propagate

            anchor = Node(axis, NodeMTG(:/, :AxisDummy, 2 * i - 1, 3))
            anchor[:Length] = 1.0
            anchor[:Width] = 0.05
            anchor[:Thickness] = 0.05

            seg = Node(axis, NodeMTG(:/, :AxisSegment, 2 * i, 3))
            seg[:Length] = 1.0
            seg[:Width] = max(0.35 - 0.03 * (i - 1), 0.12)
            seg[:Thickness] = seg[:Width]

            if i < 4
                nxt = Node(axis, NodeMTG(:<, :AxisNode, i + 1, 2))
                nxt[:Length] = 20.0
                nxt[:Width] = 0.1
                nxt[:Thickness] = 0.1
                axis = nxt
            end
        end

        local_ref_meshes = Dict(
            "AxisSegment" => RefMesh(
                "Stem",
                GeometryBasics.mesh(
                    GeometryBasics.Cylinder(Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), 0.5),
                ),
                RGB(0.58, 0.44, 0.30),
            ),
        )

        reconstruct_geometry_from_attributes!(
            mtg,
            local_ref_meshes;
            convention=conv,
            root_align=false,
        )
        return mtg
    end

    function geometrical_constraint_scene(mode::Symbol)
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        internode = Node(mtg, NodeMTG(:/, :Internode, 1, 2))

        shared_constraint = Dict{Symbol,Any}(
            :type => :cone_cylinder,
            :primary_angle => 14.0,
            :secondary_angle => 14.0,
            :cone_length => 0.35,
            :origin => (0.0, 0.0, 0.0),
            :axis => (1.0, 0.0, 0.0),
        )

        n_segments = 9
        for i in 1:n_segments
            internode[:Length] = 0.15
            internode[:Width] = max(0.08 - 0.004 * (i - 1), 0.04)
            internode[:Thickness] = internode[:Width]
            internode[:YInsertionAngle] = 19.0
            internode[:DeviationAngle] = 8.0
            mode === :constrained && (internode[:GeometricalConstraint] = shared_constraint)
            if i < n_segments
                internode = Node(internode, NodeMTG(:<, :Internode, i + 1, 2))
            end
        end

        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            root_align=false,
        )
        return mtg
    end

    function explicit_coordinate_mode_scene(mode::Symbol)
        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        i1 = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        i2 = Node(i1, NodeMTG(:<, :Internode, 2, 2))
        i3 = Node(i2, NodeMTG(:<, :Internode, 3, 2))

        for n in (i1, i2, i3)
            n[:Length] = 0.45
            n[:Width] = 0.09
            n[:Thickness] = 0.09
        end

        i1[:XX] = 0.0
        i1[:YY] = 0.0
        i1[:ZZ] = 0.0
        i1[:EndX] = 0.55
        i1[:EndY] = 0.00
        i1[:EndZ] = 0.00

        i2[:XX] = 0.86
        i2[:YY] = 0.28
        i2[:ZZ] = 0.10
        i2[:YInsertionAngle] = -30.0
        i2[:Azimuth] = 25.0

        i3[:YInsertionAngle] = 35.0
        i3[:Azimuth] = -30.0

        opts = AmapReconstructionOptions(explicit_coordinate_mode=mode)
        reconstruct_geometry_from_attributes!(
            mtg,
            ref_meshes;
            convention=conv,
            amap_options=opts,
            root_align=false,
        )
        return mtg
    end

    function _scene_bounds(scene)
        xmin_all = Inf
        xmax_all = -Inf
        ymin_all = Inf
        ymax_all = -Inf
        zmin_all = Inf
        zmax_all = -Inf

        traverse!(scene) do node
            haskey(node, :geometry) || return
            node[:geometry] === nothing && return
            mesh = refmesh_to_mesh(node)
            for p in GeometryBasics.coordinates(mesh)
                x = Float64(p[1])
                y = Float64(p[2])
                z = Float64(p[3])
                xmin_all = min(xmin_all, x)
                xmax_all = max(xmax_all, x)
                ymin_all = min(ymin_all, y)
                ymax_all = max(ymax_all, y)
                zmin_all = min(zmin_all, z)
                zmax_all = max(zmax_all, z)
            end
        end

        if !isfinite(xmin_all)
            return (-1.0, 1.0, -1.0, 1.0, -1.0, 1.0)
        end

        return (xmin_all, xmax_all, ymin_all, ymax_all, zmin_all, zmax_all)
    end

    function _plot_modes(
        modes,
        builder;
        titles=string.(modes),
        size=(1200, 360),
        ncols=length(modes),
        azimuth=1.05pi,
        elevation=0.42,
        zoom_padding=0.06,
    )
        scenes = [builder(mode) for mode in modes]
        bounds = _scene_bounds.(scenes)

        xmin_all = minimum(first.(bounds))
        xmax_all = maximum(getindex.(bounds, 2))
        ymin_all = minimum(getindex.(bounds, 3))
        ymax_all = maximum(getindex.(bounds, 4))
        zmin_all = minimum(getindex.(bounds, 5))
        zmax_all = maximum(last.(bounds))

        xpad = max((xmax_all - xmin_all) * zoom_padding, 1e-3)
        ypad = max((ymax_all - ymin_all) * zoom_padding, 1e-3)
        zpad = max((zmax_all - zmin_all) * zoom_padding, 1e-3)

        fig = Figure(size=size)
        ncols_use = max(1, Int(ncols))
        for (i, scene) in enumerate(scenes)
            row = cld(i, ncols_use)
            col = mod1(i, ncols_use)
            ax = Axis3(
                fig[row, col],
                aspect=:data,
                title=titles[i],
                azimuth=azimuth,
                elevation=elevation,
            )
            plantviz!(ax, scene, color=color_map)
            limits!(
                ax,
                xmin_all - xpad,
                xmax_all + xpad,
                ymin_all - ypad,
                ymax_all + ypad,
                zmin_all - zpad,
                zmax_all + zpad,
            )
            hidedecorations!(ax)
        end
        return fig
    end

    @test_reference "reference_images/amap_insertion_mode_2x2.png" _plot_modes(
        ("BORDER", "CENTER", "WIDTH", "HEIGHT"),
        insertion_mode_scene;
        titles=("BORDER (default)", "CENTER", "WIDTH", "HEIGHT"),
        size=(960, 760),
        ncols=2,
        azimuth=1.22pi,
        elevation=0.30,
        zoom_padding=0.035,
    )

    @test_reference "reference_images/amap_verticil_mode.png" _plot_modes(
        (:none, :rotation360),
        verticil_mode_scene;
        titles=("none: siblings overlap", "rotation360: siblings spread"),
        size=(860, 360),
        azimuth=1.18pi,
        elevation=0.38,
        zoom_padding=0.04,
    )

    @test_reference "reference_images/amap_stiffness_apply.png" _plot_modes(
        (:disabled, :propagate),
        stiffness_scene;
        titles=("StiffnessApply=false", "StiffnessApply=true"),
        size=(980, 320),
        azimuth=1.5pi,
        elevation=0.20,
        zoom_padding=0.05,
    )

    @test_reference "reference_images/amap_geometrical_constraint.png" _plot_modes(
        (:free, :constrained),
        geometrical_constraint_scene;
        titles=("No constraint", "Cone-cylinder constraint"),
        size=(920, 340),
        azimuth=1.35pi,
        elevation=0.26,
        zoom_padding=0.06,
    )

    @test_reference "reference_images/amap_explicit_coordinate_mode.png" _plot_modes(
        (:topology_default, :explicit_rewire_previous, :explicit_start_end_required),
        explicit_coordinate_mode_scene;
        titles=(
            "topology_default",
            "explicit_rewire_previous",
            "explicit_start_end_required",
        ),
        size=(1260, 320),
        ncols=3,
        azimuth=1.35pi,
        elevation=0.24,
        zoom_padding=0.07,
    )
end
