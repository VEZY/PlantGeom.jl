```@meta
CurrentModule = PlantGeom
```

# PlantGeom

Documentation for [PlantGeom](https://github.com/VEZY/PlantGeom.jl), a package for plant 3D geometry
on top of [MultiScaleTreeGraph](https://github.com/VEZY/MultiScaleTreeGraph.jl).

Main capabilities:

- OPF/OPS IO (`read_opf`, `write_opf`, `read_ops`, `write_ops`)
- 3D plotting with `plantviz` / `plantviz!`
- Geometry transformations through `Geometry` + `CoordinateTransformations`

PlantGeom reserves the `:geometry` attribute on nodes.

```@setup home
using CairoMakie
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics
using Colors

CairoMakie.activate!()

function leaf_mesh_with_petiole()
    p = [
        Point(0.07, 0.00, 0.000),
        Point(0.15, 0.044, 0.005),
        Point(0.25, 0.048, 0.010),
        Point(0.35, 0.000, 0.013),
        Point(0.25, -0.048, 0.010),
        Point(0.15, -0.044, 0.005),
    ]

    tri = GeometryBasics.TriangleFace{Int}
    blade_faces = tri[
        tri(1, 2, 3), tri(1, 3, 4), tri(1, 4, 5), tri(1, 5, 6),
        tri(3, 2, 1), tri(4, 3, 1), tri(5, 4, 1), tri(6, 5, 1),
    ]
    blade = GeometryBasics.Mesh(p, blade_faces)

    petiole = GeometryBasics.mesh(
        GeometryBasics.Cylinder(Point(0.0, 0.0, 0.0), Point(0.07, 0.0, 0.0), 0.0038),
    )

    GeometryBasics.merge([petiole, blade])
end

leaf_ref = RefMesh("leaf_with_petiole", leaf_mesh_with_petiole(), RGB(0.20, 0.62, 0.30))

function add_axis!(parent, edge, axis_id, path, radius, color)
    node = Node(parent, NodeMTG(edge, "Axis", axis_id, 2))
    node[:geometry] = ExtrudedTubeGeometry(
        path;
        n_sides=14,
        radius=radius,
        radii=collect(range(1.0, 0.70; length=length(path))),
        torsion=false,
        cap_ends=true,
        material=color,
    )
    node
end

function add_leaf!(parent, leaf_id, anchor, azimuth_deg, tilt_deg, leaf_ref)
    node = Node(parent, NodeMTG("+", "Leaf", leaf_id, 3))
    rot = PlantGeom.LinearMap(
        PlantGeom.RotZ(deg2rad(azimuth_deg)) *
        PlantGeom.AngleAxis(deg2rad(tilt_deg), 0.0, 1.0, 0.0),
    )
    tr = PlantGeom.Translation(anchor[1], anchor[2], anchor[3])
    node[:geometry] = PlantGeom.Geometry(ref_mesh=leaf_ref, transformation=PlantGeom.compose(tr, rot))
    node
end

function advance_point(p, azimuth_deg, elevation_deg, length)
    c = cosd(elevation_deg)
    Point(
        p[1] + length * c * cosd(azimuth_deg),
        p[2] + length * c * sind(azimuth_deg),
        p[3] + length * sind(elevation_deg),
    )
end

function lerp_point(a, b, t)
    Point(
        (1 - t) * a[1] + t * b[1],
        (1 - t) * a[2] + t * b[2],
        (1 - t) * a[3] + t * b[3],
    )
end

@inline branch_jitter(a, b, c, amp) = amp * sin(0.77 * a + 1.13 * b + 1.91 * c)

function grow_axis_chain!(parent, start_point, axis_counter;
    first_edge,
    n_segments,
    azimuth_deg,
    elevation_deg,
    base_length,
    taper,
    radius,
    color,
    azimuth_curve=0.0,
    elevation_curve=0.0,
)
    node = parent
    p0 = start_point
    tips = []

    for seg in 1:n_segments
        seg_length = base_length * taper^(seg - 1)
        seg_azimuth = azimuth_deg + azimuth_curve * (seg - 1)
        seg_elevation = elevation_deg + elevation_curve * (seg - 1)
        p1 = advance_point(p0, seg_azimuth, seg_elevation, seg_length)

        axis_counter[] += 1
        edge = seg == 1 ? first_edge : "<"
        seg_radius = radius * 0.84^(seg - 1)
        node = add_axis!(node, edge, axis_counter[], [p0, p1], seg_radius, color)
        push!(tips, (node=node, start=p0, tip=p1, azimuth=seg_azimuth, elevation=seg_elevation))
        p0 = p1
    end

    tips
end

function add_leaf_fan!(carrier, leaf_counter, leaf_ref; n=2, azimuth_shift=84.0, fan_step=9.0, tilt=54.0)
    n == 0 && return
    for k in 1:n
        t = 0.42 + 0.42 * (k / (n + 1))
        anchor = lerp_point(carrier.start, carrier.tip, t)
        fan = (k - (n + 1) / 2) * fan_step
        leaf_counter[] += 1
        add_leaf!(
            carrier.node,
            leaf_counter[],
            anchor,
            carrier.azimuth + azimuth_shift + fan,
            tilt,
            leaf_ref,
        )
    end
end

function build_demo_tree()
    tree = Node(NodeMTG("/", "Plant", 1, 1))

    axis_counter = Ref(0)
    leaf_counter = Ref(0)

    bark_main = RGB(0.45, 0.34, 0.24)
    bark_branch = RGB(0.41, 0.31, 0.23)
    bark_twig = RGB(0.37, 0.28, 0.21)
    bark_fine = RGB(0.47, 0.36, 0.28)

    trunk = grow_axis_chain!(
        tree,
        Point(0.0, 0.0, 0.0),
        axis_counter;
        first_edge="/",
        n_segments=9,
        azimuth_deg=8.0,
        elevation_deg=87.0,
        base_length=0.54,
        taper=0.90,
        radius=0.078,
        color=bark_main,
        azimuth_curve=2.0,
        elevation_curve=0.2,
    )

    primary_specs = [
        (seg=2, az=-96.0, el=34.0, len=0.23),
        (seg=3, az=70.0, el=35.0, len=0.26),
        (seg=4, az=-44.0, el=35.0, len=0.28),
        (seg=5, az=18.0, el=34.0, len=0.30),
        (seg=6, az=-10.0, el=35.0, len=0.30),
        (seg=7, az=58.0, el=36.0, len=0.29),
        (seg=8, az=-122.0, el=37.0, len=0.26),
        (seg=9, az=144.0, el=35.0, len=0.22),
        (seg=9, az=-170.0, el=34.0, len=0.19),
    ]

    for (p_rank, spec) in enumerate(primary_specs)
        trunk_tip = trunk[spec.seg]
        primary = grow_axis_chain!(
            trunk_tip.node,
            trunk_tip.tip,
            axis_counter;
            first_edge="+",
            n_segments=4,
            azimuth_deg=spec.az,
            elevation_deg=spec.el,
            base_length=spec.len,
            taper=0.84,
            radius=0.024 * 0.92^(p_rank - 1),
            color=bark_branch,
            azimuth_curve=4.0,
            elevation_curve=-2.2,
        )

        secondary_side_state = isodd(p_rank) ? -1.0 : 1.0
        for (seg_rank, p_tip) in enumerate(primary)
            seg_rank == 1 && continue
            secondary_selector = branch_jitter(p_rank, seg_rank, 8, 1.0)
            spawn_secondary = seg_rank == length(primary) ||
                              (seg_rank == 2 && secondary_selector > -0.15) ||
                              (seg_rank == 3 && secondary_selector > 0.55)
            spawn_secondary || continue
            secondary_side = secondary_side_state
            secondary_side_state *= -1.0
            secondary_az_jitter = branch_jitter(p_rank, seg_rank, 1, 6.0)
            secondary_el_jitter = branch_jitter(p_rank, seg_rank, 2, 1.8)

            secondary = grow_axis_chain!(
                p_tip.node,
                p_tip.tip,
                axis_counter;
                first_edge="+",
                n_segments=3,
                azimuth_deg=p_tip.azimuth + secondary_side * (36.0 + 9.0 * seg_rank) + secondary_az_jitter,
                elevation_deg=p_tip.elevation - 8.0 + secondary_el_jitter,
                base_length=0.21 * 0.90^(seg_rank - 1),
                taper=0.82,
                radius=0.011,
                color=bark_twig,
                azimuth_curve=4.6 * secondary_side,
                elevation_curve=-2.4,
            )

            o4_side_state = -secondary_side
            for (s_rank, s_tip) in enumerate(secondary)
                o4_side = o4_side_state
                o4_side_state *= -1.0
                o4_az_jitter = branch_jitter(p_rank, seg_rank, s_rank, 5.0)
                o4_el_jitter = branch_jitter(p_rank, seg_rank, s_rank + 5, 1.4)
                order4 = grow_axis_chain!(
                    s_tip.node,
                    s_tip.tip,
                    axis_counter;
                    first_edge="+",
                    n_segments=1,
                    azimuth_deg=s_tip.azimuth + o4_side * (40.0 + 7.0 * s_rank) + o4_az_jitter,
                    elevation_deg=s_tip.elevation - 6.0 + o4_el_jitter,
                    base_length=0.145 * 0.90^(s_rank - 1),
                    taper=0.9,
                    radius=0.0085,
                    color=bark_fine,
                )

                o4_tip = order4[end]
                o5_side = -o4_side
                o5_az_jitter = branch_jitter(p_rank + 2, seg_rank, s_rank, 4.0)
                o5_el_jitter = branch_jitter(p_rank + 3, seg_rank, s_rank, 1.1)
                order5 = grow_axis_chain!(
                    o4_tip.node,
                    o4_tip.tip,
                    axis_counter;
                    first_edge="+",
                    n_segments=1,
                    azimuth_deg=o4_tip.azimuth + o5_side * 36.0 + o5_az_jitter,
                    elevation_deg=o4_tip.elevation - 5.0 + o5_el_jitter,
                    base_length=0.09,
                    taper=0.9,
                    radius=0.0052,
                    color=bark_fine,
                )

                if s_rank >= length(secondary) - 1 && isodd(seg_rank + p_rank)
                    add_leaf_fan!(
                        o4_tip,
                        leaf_counter,
                        leaf_ref;
                        n=1,
                        azimuth_shift=66.0 * o4_side,
                        fan_step=8.0,
                        tilt=12.0,
                    )
                end

                if s_rank >= length(secondary) - 1 || seg_rank == length(primary)
                    add_leaf_fan!(
                        order5[end],
                        leaf_counter,
                        leaf_ref;
                        n=(s_rank == length(secondary) && seg_rank == length(primary) ? 2 : 1),
                        azimuth_shift=78.0 * o5_side,
                        fan_step=7.0,
                        tilt=16.0,
                    )
                end
            end
        end
    end

    tree
end

tree_demo = build_demo_tree()
```

## Quick Example

```@example home
plantviz(tree_demo, figure=(size=(980, 980),))
```

## Reproduce in a Script

!!! details "Code to reproduce this image"
    ```julia
    using CairoMakie
    using PlantGeom
    using MultiScaleTreeGraph
    using GeometryBasics
    using Colors

    CairoMakie.activate!()

    function leaf_mesh_with_petiole()
        p = [
            Point(0.07, 0.00, 0.000),
            Point(0.15, 0.044, 0.005),
            Point(0.25, 0.048, 0.010),
            Point(0.35, 0.000, 0.013),
            Point(0.25, -0.048, 0.010),
            Point(0.15, -0.044, 0.005),
        ]

        tri = GeometryBasics.TriangleFace{Int}
        blade_faces = tri[
            tri(1, 2, 3), tri(1, 3, 4), tri(1, 4, 5), tri(1, 5, 6),
            tri(3, 2, 1), tri(4, 3, 1), tri(5, 4, 1), tri(6, 5, 1),
        ]
        blade = GeometryBasics.Mesh(p, blade_faces)

        petiole = GeometryBasics.mesh(
            GeometryBasics.Cylinder(Point(0.0, 0.0, 0.0), Point(0.07, 0.0, 0.0), 0.0038),
        )

        GeometryBasics.merge([petiole, blade])
    end

    leaf_ref = RefMesh("leaf_with_petiole", leaf_mesh_with_petiole(), RGB(0.20, 0.62, 0.30))

    function add_axis!(parent, edge, axis_id, path, radius, color)
        node = Node(parent, NodeMTG(edge, "Axis", axis_id, 2))
        node[:geometry] = ExtrudedTubeGeometry(
            path;
            n_sides=14,
            radius=radius,
            radii=collect(range(1.0, 0.70; length=length(path))),
            torsion=false,
            cap_ends=true,
            material=color,
        )
        node
    end

    function add_leaf!(parent, leaf_id, anchor, azimuth_deg, tilt_deg, leaf_ref)
        node = Node(parent, NodeMTG("+", "Leaf", leaf_id, 3))
        rot = PlantGeom.LinearMap(
            PlantGeom.RotZ(deg2rad(azimuth_deg)) *
            PlantGeom.AngleAxis(deg2rad(tilt_deg), 0.0, 1.0, 0.0),
        )
        tr = PlantGeom.Translation(anchor[1], anchor[2], anchor[3])
        node[:geometry] = PlantGeom.Geometry(ref_mesh=leaf_ref, transformation=PlantGeom.compose(tr, rot))
        node
    end

    function advance_point(p, azimuth_deg, elevation_deg, length)
        c = cosd(elevation_deg)
        Point(
            p[1] + length * c * cosd(azimuth_deg),
            p[2] + length * c * sind(azimuth_deg),
            p[3] + length * sind(elevation_deg),
        )
    end

    function lerp_point(a, b, t)
        Point(
            (1 - t) * a[1] + t * b[1],
            (1 - t) * a[2] + t * b[2],
            (1 - t) * a[3] + t * b[3],
        )
    end

    @inline branch_jitter(a, b, c, amp) = amp * sin(0.77 * a + 1.13 * b + 1.91 * c)

    function grow_axis_chain!(parent, start_point, axis_counter;
        first_edge,
        n_segments,
        azimuth_deg,
        elevation_deg,
        base_length,
        taper,
        radius,
        color,
        azimuth_curve=0.0,
        elevation_curve=0.0,
    )
        node = parent
        p0 = start_point
        tips = []

        for seg in 1:n_segments
            seg_length = base_length * taper^(seg - 1)
            seg_azimuth = azimuth_deg + azimuth_curve * (seg - 1)
            seg_elevation = elevation_deg + elevation_curve * (seg - 1)
            p1 = advance_point(p0, seg_azimuth, seg_elevation, seg_length)

            axis_counter[] += 1
            edge = seg == 1 ? first_edge : "<"
            seg_radius = radius * 0.84^(seg - 1)
            node = add_axis!(node, edge, axis_counter[], [p0, p1], seg_radius, color)
            push!(tips, (node=node, start=p0, tip=p1, azimuth=seg_azimuth, elevation=seg_elevation))
            p0 = p1
        end

        tips
    end

    function add_leaf_fan!(carrier, leaf_counter, leaf_ref; n=2, azimuth_shift=84.0, fan_step=9.0, tilt=54.0)
        n == 0 && return
        for k in 1:n
            t = 0.42 + 0.42 * (k / (n + 1))
            anchor = lerp_point(carrier.start, carrier.tip, t)
            fan = (k - (n + 1) / 2) * fan_step
            leaf_counter[] += 1
            add_leaf!(
                carrier.node,
                leaf_counter[],
                anchor,
                carrier.azimuth + azimuth_shift + fan,
                tilt,
                leaf_ref,
            )
        end
    end

    function build_demo_tree()
        tree = Node(NodeMTG("/", "Plant", 1, 1))

        axis_counter = Ref(0)
        leaf_counter = Ref(0)

        bark_main = RGB(0.45, 0.34, 0.24)
        bark_branch = RGB(0.41, 0.31, 0.23)
        bark_twig = RGB(0.37, 0.28, 0.21)
        bark_fine = RGB(0.47, 0.36, 0.28)

        trunk = grow_axis_chain!(
            tree,
            Point(0.0, 0.0, 0.0),
            axis_counter;
            first_edge="/",
            n_segments=9,
            azimuth_deg=8.0,
            elevation_deg=87.0,
            base_length=0.54,
            taper=0.90,
            radius=0.078,
            color=bark_main,
            azimuth_curve=2.0,
            elevation_curve=0.2,
        )

    primary_specs = [
        (seg=2, az=-96.0, el=34.0, len=0.23),
        (seg=3, az=70.0, el=35.0, len=0.26),
        (seg=4, az=-44.0, el=35.0, len=0.28),
        (seg=5, az=18.0, el=34.0, len=0.30),
        (seg=6, az=-10.0, el=35.0, len=0.30),
        (seg=7, az=58.0, el=36.0, len=0.29),
        (seg=8, az=-122.0, el=37.0, len=0.26),
        (seg=9, az=144.0, el=35.0, len=0.22),
        (seg=9, az=-170.0, el=34.0, len=0.19),
    ]

        for (p_rank, spec) in enumerate(primary_specs)
            trunk_tip = trunk[spec.seg]
            primary = grow_axis_chain!(
                trunk_tip.node,
                trunk_tip.tip,
                axis_counter;
                first_edge="+",
                n_segments=4,
                azimuth_deg=spec.az,
                elevation_deg=spec.el,
                base_length=spec.len,
                taper=0.84,
                radius=0.024 * 0.92^(p_rank - 1),
                color=bark_branch,
                azimuth_curve=4.0,
                elevation_curve=-2.2,
            )

        secondary_side_state = isodd(p_rank) ? -1.0 : 1.0
        for (seg_rank, p_tip) in enumerate(primary)
            seg_rank == 1 && continue
            secondary_selector = branch_jitter(p_rank, seg_rank, 8, 1.0)
            spawn_secondary = seg_rank == length(primary) ||
                              (seg_rank == 2 && secondary_selector > -0.15) ||
                              (seg_rank == 3 && secondary_selector > 0.55)
            spawn_secondary || continue
            secondary_side = secondary_side_state
            secondary_side_state *= -1.0
            secondary_az_jitter = branch_jitter(p_rank, seg_rank, 1, 6.0)
            secondary_el_jitter = branch_jitter(p_rank, seg_rank, 2, 1.8)

                secondary = grow_axis_chain!(
                    p_tip.node,
                    p_tip.tip,
                    axis_counter;
                    first_edge="+",
                    n_segments=3,
                    azimuth_deg=p_tip.azimuth + secondary_side * (36.0 + 9.0 * seg_rank) + secondary_az_jitter,
                    elevation_deg=p_tip.elevation - 8.0 + secondary_el_jitter,
                    base_length=0.21 * 0.90^(seg_rank - 1),
                    taper=0.82,
                    radius=0.011,
                    color=bark_twig,
                    azimuth_curve=4.6 * secondary_side,
                    elevation_curve=-2.4,
                )

                o4_side_state = -secondary_side
                for (s_rank, s_tip) in enumerate(secondary)
                    o4_side = o4_side_state
                    o4_side_state *= -1.0
                    o4_az_jitter = branch_jitter(p_rank, seg_rank, s_rank, 5.0)
                    o4_el_jitter = branch_jitter(p_rank, seg_rank, s_rank + 5, 1.4)
                    order4 = grow_axis_chain!(
                        s_tip.node,
                        s_tip.tip,
                        axis_counter;
                        first_edge="+",
                        n_segments=1,
                        azimuth_deg=s_tip.azimuth + o4_side * (40.0 + 7.0 * s_rank) + o4_az_jitter,
                        elevation_deg=s_tip.elevation - 6.0 + o4_el_jitter,
                        base_length=0.145 * 0.90^(s_rank - 1),
                        taper=0.9,
                        radius=0.0085,
                        color=bark_fine,
                    )

                    o4_tip = order4[end]
                    o5_side = -o4_side
                    o5_az_jitter = branch_jitter(p_rank + 2, seg_rank, s_rank, 4.0)
                    o5_el_jitter = branch_jitter(p_rank + 3, seg_rank, s_rank, 1.1)
                    order5 = grow_axis_chain!(
                        o4_tip.node,
                        o4_tip.tip,
                        axis_counter;
                        first_edge="+",
                        n_segments=1,
                        azimuth_deg=o4_tip.azimuth + o5_side * 36.0 + o5_az_jitter,
                        elevation_deg=o4_tip.elevation - 5.0 + o5_el_jitter,
                        base_length=0.09,
                        taper=0.9,
                        radius=0.0052,
                        color=bark_fine,
                    )

                    if s_rank >= length(secondary) - 1 && isodd(seg_rank + p_rank)
                        add_leaf_fan!(
                            o4_tip,
                            leaf_counter,
                            leaf_ref;
                            n=1,
                            azimuth_shift=66.0 * o4_side,
                            fan_step=8.0,
                            tilt=12.0,
                        )
                    end

                    if s_rank >= length(secondary) - 1 || seg_rank == length(primary)
                        add_leaf_fan!(
                            order5[end],
                            leaf_counter,
                            leaf_ref;
                            n=(s_rank == length(secondary) && seg_rank == length(primary) ? 2 : 1),
                            azimuth_shift=78.0 * o5_side,
                            fan_step=7.0,
                            tilt=16.0,
                        )
                    end
                end
            end
        end

        tree
    end

    tree_demo = build_demo_tree()

    plantviz(tree_demo, figure=(size=(980, 980),))
    ```
