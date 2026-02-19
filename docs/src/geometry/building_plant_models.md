# Building Plant Models

This page has two workflows:

1. **Simple tutorial**: read a small `.mtg` file and reconstruct geometry directly from attributes.
2. **Advanced tutorial**: build topology and attributes from scratch, including local/global angle control.

All reference meshes below follow the AMAP standard direction: organ length is along local `+X`.

```@setup buildgeom
using PlantGeom
using MultiScaleTreeGraph
using Colors
using CairoMakie
using GeometryBasics
using CoordinateTransformations
using Rotations

CairoMakie.activate!()

const Tri = GeometryBasics.TriangleFace{Int}

function cylinder_mesh_x(radius=0.5, length=1.0)
    c = GeometryBasics.Cylinder(
        Point(0.0, 0.0, 0.0),
        Point(length, 0.0, 0.0),
        radius,
    )
    GeometryBasics.mesh(c)
end

function leaf_mesh_x()
    vertices = [
        Point(0.0, -0.05, 0.0),
        Point(0.0, 0.05, 0.0),
        Point(0.2, 0.0, 0.0),
        Point(1.2, 0.0, 0.0),
        Point(0.7, -0.45, 0.0),
        Point(0.7, 0.45, 0.0),
    ]

    faces = Tri[
        Tri(1, 2, 3),
        Tri(3, 5, 4),
        Tri(3, 6, 4),
    ]

    GeometryBasics.Mesh(vertices, faces)
end

refmesh_stem = RefMesh("Stem", cylinder_mesh_x(0.5, 1.0), RGB(0.55, 0.45, 0.35))
refmesh_leaf = RefMesh("Leaf", leaf_mesh_x(), RGB(0.1, 0.5, 0.2))
refmesh_root = RefMesh("Root", cylinder_mesh_x(0.5, 1.0), RGB(0.45, 0.35, 0.25))

ref_meshes_simple = Dict(
    "Internode" => refmesh_stem,
    "Leaf" => refmesh_leaf,
)

ref_meshes_advanced = Dict(
    "Internode" => refmesh_stem,
    "Leaf" => refmesh_leaf,
    "RootSegment" => refmesh_root,
)

amap_convention = default_amap_geometry_convention()

leaf_global_heading_convention = GeometryConvention(
    scale_map=amap_convention.scale_map,
    angle_map=[
        (names=[:XInsertionAngle], axis=:x, frame=:local, unit=:deg, pivot=:origin),
        (names=[:YInsertionAngle], axis=:y, frame=:local, unit=:deg, pivot=:origin),
        (names=[:Heading], axis=:z, frame=:global, unit=:deg, pivot=(:pivot_x, :pivot_y, :pivot_z)),
        (names=[:XEuler], axis=:x, frame=:local, unit=:deg, pivot=:origin),
    ],
    translation_map=amap_convention.translation_map,
    length_axis=:x,
)

function build_mtg_from_scratch(n_internodes=8, n_roots=4)
    mtg = Node(NodeMTG("/", "Plant", 1, 1))

    stem = mtg
    for i in 1:n_internodes
        stem = Node(stem, NodeMTG(i == 1 ? "/" : "<", "Internode", i, 2))
        Node(stem, NodeMTG("+", "Leaf", i, 2))
    end

    roots = mtg
    for i in 1:n_roots
        roots = Node(roots, NodeMTG(i == 1 ? "/" : "<", "RootSegment", i, 2))
    end

    mtg
end

function assign_advanced_attributes!(mtg)
    internode_rank = 0
    leaf_rank = 0
    root_rank = 0

    traverse!(mtg) do node
        organ = symbol(node)

        if organ == "Internode"
            internode_rank += 1
            node[:Length] = 0.30 * 0.95^(internode_rank - 1)
            node[:Width] = 0.08 * 0.93^(internode_rank - 1)
            node[:Thickness] = node[:Width]
            node[:XEuler] = 0.0
            node[:YEuler] = 3.0 * sin(internode_rank / 3)
            node[:ZEuler] = 0.0
        elseif organ == "Leaf"
            leaf_rank += 1
            node[:Length] = 0.20 + 0.012 * leaf_rank
            node[:Width] = 0.52 * node[:Length]
            node[:Thickness] = 1e-3
            node[:Offset] = 0.82 * (0.30 * 0.95^(leaf_rank - 1))
            node[:BorderInsertionOffset] = 0.04
            node[:XInsertionAngle] = 45.0 + 90.0 * (leaf_rank - 1)
            node[:YInsertionAngle] = 48.0
            node[:XEuler] = -25.0

            # Global heading around origin for demonstration.
            node[:Heading] = 10.0 * sin(leaf_rank / 2)
            node[:pivot_x] = 0.0
            node[:pivot_y] = 0.0
            node[:pivot_z] = 0.0
        elseif organ == "RootSegment"
            root_rank += 1
            node[:Length] = 0.45 * 0.92^(root_rank - 1)
            node[:Width] = 0.05 * 0.90^(root_rank - 1)
            node[:Thickness] = node[:Width]
            node[:YEuler] = 180.0
            node[:ZEuler] = 0.0
        end
    end

    mtg
end
```

## 1. Simple Tutorial: Read an MTG File and Reconstruct Geometry

This example uses `/Users/rvezy/Documents/dev/PlantGeom/test/files/reconstruction_standard.mtg`.

```@example buildgeom
simple_mtg_file = joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg")
mtg_simple = read_mtg(simple_mtg_file)

set_geometry_from_attributes!(
    mtg_simple,
    ref_meshes_simple;
    convention=amap_convention,
)

length(descendants(mtg_simple, :geometry; ignore_nothing=true, self=true))
```

```@example buildgeom
plantviz(mtg_simple, color=Dict("Stem" => :tan4, "Leaf" => :forestgreen))
```

!!! details "Code to generate the MTG file used above"
    ```julia
    using MultiScaleTreeGraph

    function write_reconstruction_demo_mtg(path)
        mtg = Node(NodeMTG("/", "Plant", 1, 1))

        stem = mtg
        for i in 1:4
            stem = Node(stem, NodeMTG(i == 1 ? "/" : "<", "Internode", i, 2))
            stem[:Length] = 0.28 * 0.94^(i - 1)
            stem[:Width] = 0.035 * 0.95^(i - 1)
            stem[:Thickness] = stem[:Width]
            stem[:YEuler] = 3.0 * sin(i / 2)

            leaf = Node(stem, NodeMTG("+", "Leaf", i, 2))
            leaf[:Length] = 0.22 + 0.015 * i
            leaf[:Width] = 0.11 + 0.006 * i
            leaf[:Thickness] = 0.002
            leaf[:XInsertionAngle] = 45.0 + 90.0 * (i - 1)
            leaf[:YInsertionAngle] = 52.0 + 2.0 * sin(i)
            leaf[:XEuler] = -18.0
            leaf[:Offset] = 0.82 * stem[:Length]
            leaf[:BorderInsertionOffset] = 0.5 * stem[:Width]
        end

        write_mtg(path, mtg)
        return path
    end

    write_reconstruction_demo_mtg("reconstruction_standard.mtg")
    ```

!!! details "Code to reproduce this image"
    ```julia
    using PlantGeom
    using MultiScaleTreeGraph
    using GeometryBasics
    using Colors
    using CairoMakie

    CairoMakie.activate!()

    const Tri = GeometryBasics.TriangleFace{Int}

    function cylinder_mesh_x(radius=0.5, length=1.0)
        GeometryBasics.mesh(
            GeometryBasics.Cylinder(
                Point(0.0, 0.0, 0.0),
                Point(length, 0.0, 0.0),
                radius,
            ),
        )
    end

    function leaf_mesh_x()
        GeometryBasics.Mesh(
            [
                Point(0.0, -0.05, 0.0),
                Point(0.0, 0.05, 0.0),
                Point(0.2, 0.0, 0.0),
                Point(1.2, 0.0, 0.0),
                Point(0.7, -0.45, 0.0),
                Point(0.7, 0.45, 0.0),
            ],
            Tri[
                Tri(1, 2, 3),
                Tri(3, 5, 4),
                Tri(3, 6, 4),
            ],
        )
    end

    refmesh_stem = RefMesh("Stem", cylinder_mesh_x(0.5, 1.0), RGB(0.55, 0.45, 0.35))
    refmesh_leaf = RefMesh("Leaf", leaf_mesh_x(), RGB(0.1, 0.5, 0.2))

    ref_meshes = Dict(
        "Internode" => refmesh_stem,
        "Leaf" => refmesh_leaf,
    )

    mtg_file = joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg")
    mtg = read_mtg(mtg_file)

    set_geometry_from_attributes!(
        mtg,
        ref_meshes;
        convention=default_amap_geometry_convention(),
    )

    plantviz(mtg, color=Dict("Stem" => :tan4, "Leaf" => :forestgreen))
    ```

## Conventions and Composition Rules

`set_geometry_from_attributes!` with an MTG uses both attribute mapping and topology.

| Concept | Behavior |
| --- | --- |
| Alias resolution | First matching alias is used (`Length`, `length`, `L`, ...). |
| Local angle (`frame=:local`) | Composed in local coordinates: `T = T ∘ R`. |
| Global angle (`frame=:global`) | Applied in world frame around a pivot: `T = recenter(R, pivot) ∘ T`. |
| Pivot | `:origin`, attribute tuple like `(:pivot_x,:pivot_y,:pivot_z)`, or numeric tuple. |
| Translation attributes | If `XX/YY/ZZ` are present, they are used directly. |
| Missing translation | Topological reconstruction is used (`<`, `+`, `/` rules below). |

Topological placement defaults (AMAP-style):

| Link | Placement rule when `XX/YY/ZZ` are missing |
| --- | --- |
| `<` | Successor starts at predecessor top. |
| `+` | Ramification starts at bearer `Offset` (or bearer `Length`) and uses `BORDER` mode by default (`BorderInsertionOffset`, else bearer top width / 2). Use `InsertionMode="CENTER"` to disable border offset. |
| `/` | Component starts at parent base. |

## 2. Advanced Tutorial: Build Topology and Attributes from Scratch

```@example buildgeom
mtg_advanced = build_mtg_from_scratch(8, 4)
assign_advanced_attributes!(mtg_advanced)

set_geometry_from_attributes!(
    mtg_advanced,
    ref_meshes_advanced;
    convention=amap_convention,
    conventions=Dict("Leaf" => leaf_global_heading_convention),
)

length(descendants(mtg_advanced, :geometry; ignore_nothing=true, self=true))
```

```@example buildgeom
plantviz(
    mtg_advanced,
    color=Dict("Stem" => :tan3, "Leaf" => :green4, "Root" => :sienna4),
)
```

!!! details "Code to reproduce this image"
    ```julia
    using PlantGeom
    using MultiScaleTreeGraph
    using GeometryBasics
    using Colors
    using CairoMakie

    CairoMakie.activate!()

    const Tri = GeometryBasics.TriangleFace{Int}

    function cylinder_mesh_x(radius=0.5, length=1.0)
        GeometryBasics.mesh(
            GeometryBasics.Cylinder(
                Point(0.0, 0.0, 0.0),
                Point(length, 0.0, 0.0),
                radius,
            ),
        )
    end

    function leaf_mesh_x()
        GeometryBasics.Mesh(
            [
                Point(0.0, -0.05, 0.0),
                Point(0.0, 0.05, 0.0),
                Point(0.2, 0.0, 0.0),
                Point(1.2, 0.0, 0.0),
                Point(0.7, -0.45, 0.0),
                Point(0.7, 0.45, 0.0),
            ],
            Tri[
                Tri(1, 2, 3),
                Tri(3, 5, 4),
                Tri(3, 6, 4),
            ],
        )
    end

    function build_mtg(n_internodes=8, n_roots=4)
        mtg = Node(NodeMTG("/", "Plant", 1, 1))

        stem = mtg
        for i in 1:n_internodes
            stem = Node(stem, NodeMTG(i == 1 ? "/" : "<", "Internode", i, 2))
            Node(stem, NodeMTG("+", "Leaf", i, 2))
        end

        roots = mtg
        for i in 1:n_roots
            roots = Node(roots, NodeMTG(i == 1 ? "/" : "<", "RootSegment", i, 2))
        end

        mtg
    end

    function add_attributes!(mtg)
        internode_rank = 0
        leaf_rank = 0
        root_rank = 0

        traverse!(mtg) do node
            organ = symbol(node)

            if organ == "Internode"
                internode_rank += 1
                node[:Length] = 0.30 * 0.95^(internode_rank - 1)
                node[:Width] = 0.08 * 0.93^(internode_rank - 1)
                node[:Thickness] = node[:Width]
                node[:YEuler] = 3.0 * sin(internode_rank / 3)
            elseif organ == "Leaf"
                leaf_rank += 1
                node[:Length] = 0.20 + 0.012 * leaf_rank
                node[:Width] = 0.52 * node[:Length]
                node[:Thickness] = 1e-3
                node[:Offset] = 0.82 * (0.30 * 0.95^(leaf_rank - 1))
                node[:BorderInsertionOffset] = 0.04
                node[:XInsertionAngle] = 45.0 + 90.0 * (leaf_rank - 1)
                node[:YInsertionAngle] = 48.0
                node[:XEuler] = -25.0
                node[:Heading] = 10.0 * sin(leaf_rank / 2)
                node[:pivot_x] = 0.0
                node[:pivot_y] = 0.0
                node[:pivot_z] = 0.0
            elseif organ == "RootSegment"
                root_rank += 1
                node[:Length] = 0.45 * 0.92^(root_rank - 1)
                node[:Width] = 0.05 * 0.90^(root_rank - 1)
                node[:Thickness] = node[:Width]
                node[:YEuler] = 180.0
            end
        end

        mtg
    end

    refmesh_stem = RefMesh("Stem", cylinder_mesh_x(0.5, 1.0), RGB(0.55, 0.45, 0.35))
    refmesh_leaf = RefMesh("Leaf", leaf_mesh_x(), RGB(0.1, 0.5, 0.2))
    refmesh_root = RefMesh("Root", cylinder_mesh_x(0.5, 1.0), RGB(0.45, 0.35, 0.25))

    ref_meshes = Dict(
        "Internode" => refmesh_stem,
        "Leaf" => refmesh_leaf,
        "RootSegment" => refmesh_root,
    )

    base = default_amap_geometry_convention()
    leaf_conv = GeometryConvention(
        scale_map=base.scale_map,
        angle_map=[
            (names=[:XInsertionAngle], axis=:x, frame=:local, unit=:deg, pivot=:origin),
            (names=[:YInsertionAngle], axis=:y, frame=:local, unit=:deg, pivot=:origin),
            (names=[:Heading], axis=:z, frame=:global, unit=:deg, pivot=(:pivot_x, :pivot_y, :pivot_z)),
            (names=[:XEuler], axis=:x, frame=:local, unit=:deg, pivot=:origin),
        ],
        translation_map=base.translation_map,
        length_axis=:x,
    )

    mtg = build_mtg(8, 4)
    add_attributes!(mtg)

    set_geometry_from_attributes!(
        mtg,
        ref_meshes;
        convention=base,
        conventions=Dict("Leaf" => leaf_conv),
    )

    plantviz(mtg, color=Dict("Stem" => :tan3, "Leaf" => :green4, "Root" => :sienna4))
    ```

## Manual Transform Composition (When Needed)

If you need full control, compose transforms directly with `CoordinateTransformations`:

```julia
manual_t = IdentityTransformation()
manual_t = manual_t ∘ LinearMap(Diagonal([0.30, 0.08, 0.08]))
manual_t = manual_t ∘ LinearMap(RotMatrix(AngleAxis(deg2rad(-35.0), 0.0, 1.0, 0.0)))
manual_t = Translation(0.5, 0.0, 0.0) ∘ manual_t

node[:geometry] = Geometry(ref_mesh=refmesh_stem, transformation=manual_t)
```
