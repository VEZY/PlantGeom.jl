# Building Plant Models

This page is tutorial-first:

1. Read a simple MTG file and reconstruct geometry from attributes.
2. Build a plant from scratch with custom conventions (including local/global angles).

For detailed AMAP conventions, alias tables, precedence rules, and parity status, see:

- [`AMAP Quickstart`](amap_quickstart.md)
- [`AMAP Conventions Reference`](amap_conventions_reference.md)
- [`AMAP Parity Matrix`](amap_parity_matrix.md)

All reference meshes below follow the AMAP standard direction: organ length along local `+X`.

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

## 1. Simple Tutorial: Read an MTG and Reconstruct from Attributes

This example uses `test/files/reconstruction_standard.mtg` from PlantGeom.

!!! details "Content of `reconstruction_standard.mtg`"
    ```text
    CODE:	FORM-A
    
    CLASSES:
    SYMBOL	SCALE	DECOMPOSITION	INDEXATION	DEFINITION
    Plant	1	FREE	FREE	IMPLICIT
    Internode	2	FREE	FREE	IMPLICIT
    Leaf	2	FREE	FREE	IMPLICIT
    
    DESCRIPTION:
    LEFT	RIGHT	RELTYPE	MAX
    
    FEATURES:
    NAME	TYPE
    Thickness	REAL
    Length	REAL
    Width	REAL
    YEuler	REAL
    XEuler	REAL
    XInsertionAngle	REAL
    YInsertionAngle	REAL
    Offset	REAL
    BorderInsertionOffset	REAL
    
    MTG:
    ENTITY-CODE		Thickness	Length	Width	YEuler	XEuler	XInsertionAngle	YInsertionAngle	Offset	BorderInsertionOffset
    /Plant1										
    ^/Internode1		0.035	0.28	0.035	1.438276615812609					
    	+Leaf1	0.002	0.235	0.116		-18.0	45.0	53.68294196961579	0.2296	0.0175
    ^<Internode2		0.03325	0.2632	0.03325	2.5244129544236893					
    	+Leaf2	0.002	0.25	0.122		-18.0	135.0	53.81859485365136	0.215824	0.016625
    ^<Internode3		0.031587500000000004	0.24740800000000002	0.031587500000000004	2.9924849598121632					
    	+Leaf3	0.002	0.265	0.128		-18.0	225.0	52.28224001611974	0.20287456	0.015793750000000002
    ^<Internode4		0.030008125	0.23256352	0.030008125	2.727892280477045					
    ^+Leaf4		0.002	0.28	0.134		-18.0	315.0	50.48639500938415	0.1907020864	0.0150040625
    ```

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

## 2. Advanced Tutorial: Build Plant Topology and Attributes from Scratch

Use a base AMAP convention for most organs, and a leaf-specific convention to add a global heading angle around a configurable pivot.

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

## 3. Manual Transform Composition (Advanced)

When you need full control, compose transforms directly with `CoordinateTransformations`:

```julia
manual_t = IdentityTransformation()
manual_t = manual_t ∘ LinearMap(Diagonal([0.30, 0.08, 0.08]))
manual_t = manual_t ∘ LinearMap(RotMatrix(AngleAxis(deg2rad(-35.0), 0.0, 1.0, 0.0)))
manual_t = Translation(0.5, 0.0, 0.0) ∘ manual_t

node[:geometry] = Geometry(ref_mesh=refmesh_stem, transformation=manual_t)
```
