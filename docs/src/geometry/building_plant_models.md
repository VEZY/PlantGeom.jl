# Building Plant Models

This page has two workflows:

1. **Simple tutorial**: read a small `.mtg` file and reconstruct geometry from attributes.
2. **Advanced tutorial**: build topology and geometry from scratch with explicit conventions.

```@setup buildgeom
using PlantGeom
using MultiScaleTreeGraph
using Colors
using CairoMakie
using GeometryBasics
using CoordinateTransformations
using Rotations
using LinearAlgebra

CairoMakie.activate!()

const Tri = GeometryBasics.TriangleFace{Int}

function cylinder_mesh(radius=0.5, height=1.0)
    c = GeometryBasics.Cylinder(
        Point(0.0, 0.0, 0.0),
        Point(0.0, 0.0, height),
        radius,
    )
    GeometryBasics.mesh(c)
end

function leaf_mesh()
    vertices = [
        Point(0.0, -0.05, 0.0),
        Point(0.0, 0.05, 0.0),
        Point(0.2, 0.0, 0.0),
        Point(1.2, 0.0, 0.0),
        Point(0.7, -0.5, 0.0),
        Point(0.7, 0.5, 0.0),
    ]

    faces = Tri[
        Tri(1, 2, 3),
        Tri(3, 5, 4),
        Tri(3, 6, 4),
    ]

    GeometryBasics.Mesh(vertices, faces)
end

refmesh_stem = RefMesh("Stem", cylinder_mesh(0.5, 1.0), RGB(0.55, 0.45, 0.35))
refmesh_leaf = RefMesh("Leaf", leaf_mesh(), RGB(0.1, 0.5, 0.2))
refmesh_root = RefMesh("Root", cylinder_mesh(0.5, 1.0), RGB(0.45, 0.35, 0.25))

stem_convention = default_geometry_convention()

leaf_convention = GeometryConvention(
    scale_map=stem_convention.scale_map,
    angle_map=stem_convention.angle_map,
    translation_map=stem_convention.translation_map,
    length_axis=:x,
)

leaf_convention_with_global_heading = GeometryConvention(
    scale_map=stem_convention.scale_map,
    angle_map=[
        (names=[:Pitch, :YEuler], axis=:y, frame=:local, unit=:deg, pivot=:origin),
        (names=[:Heading, :ZEuler], axis=:z, frame=:global, unit=:deg, pivot=(:pivot_x, :pivot_y, :pivot_z)),
        (names=[:Roll, :XEuler], axis=:x, frame=:local, unit=:deg, pivot=:origin),
    ],
    translation_map=stem_convention.translation_map,
    length_axis=:x,
)

function reconstruct_simple_from_attributes!(mtg, stem_refmesh, leaf_refmesh)
    current_height = 0.0
    leaf_rank = 0
    stem_radius = 0.012

    traverse!(mtg) do node
        organ = symbol(node)

        if organ == "Internode"
            node[:Length] = haskey(node, :Length) ? node[:Length] : 0.10
            node[:Width] = haskey(node, :Width) ? node[:Width] : 0.02
            node[:Thickness] = node[:Width]
            node[:YEuler] = haskey(node, :YEuler) ? node[:YEuler] : 0.0
            node[:ZEuler] = haskey(node, :ZEuler) ? node[:ZEuler] : 0.0
            node[:xx] = 0.0
            node[:yy] = 0.0
            node[:zz] = current_height

            set_geometry_from_attributes!(node, stem_refmesh; convention=stem_convention)

            current_height += node[:Length]
        elseif organ == "Leaf"
            leaf_rank += 1
            heading = (leaf_rank - 1) * 137.5

            node[:Length] = haskey(node, :Length) ? node[:Length] : 0.2
            node[:Width] = haskey(node, :Width) ? node[:Width] : 0.08
            node[:Thickness] = 1e-3

            node[:XEuler] = -20.0
            node[:YEuler] = -35.0
            node[:ZEuler] = heading

            # Keep leaves on a small radial offset around the stem to avoid overlap.
            node[:xx] = stem_radius * cosd(heading)
            node[:yy] = stem_radius * sind(heading)
            node[:zz] = current_height - 0.02

            set_geometry_from_attributes!(node, leaf_refmesh; convention=leaf_convention)
        end
    end

    mtg
end

function build_mtg_from_scratch(n_internodes=7, n_roots=3)
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

function add_geometry_from_scratch!(mtg, stem_refmesh, leaf_refmesh, root_refmesh)
    current_height = 0.0
    root_depth = -0.45

    internode_rank = 0
    root_rank = 0
    leaf_rank = 0

    traverse!(mtg) do node
        organ = symbol(node)

        if organ == "Internode"
            internode_rank += 1
            length_i = 0.32 * 0.95^(internode_rank - 1)
            width_i = 0.09 * 0.93^(internode_rank - 1)

            node[:Length] = length_i
            node[:Width] = width_i
            node[:Thickness] = width_i
            node[:XEuler] = 0.0
            node[:YEuler] = 0.0
            node[:ZEuler] = 0.0
            node[:xx] = 0.0
            node[:yy] = 0.0
            node[:zz] = current_height

            set_geometry_from_attributes!(node, stem_refmesh; convention=stem_convention)
            current_height += length_i
        elseif organ == "Leaf"
            leaf_rank += 1

            heading = (leaf_rank - 1) * 137.5
            leaf_length = 0.18 + 0.012 * leaf_rank
            leaf_width = 0.52 * leaf_length
            stem_radius = 0.045

            node[:Length] = leaf_length
            node[:Width] = leaf_width
            node[:Thickness] = 1e-3

            node[:Pitch] = -35.0
            node[:Roll] = 8.0 * sin(leaf_rank / 2)
            node[:Heading] = heading

            node[:xx] = stem_radius * cosd(heading)
            node[:yy] = stem_radius * sind(heading)
            node[:zz] = current_height - 0.03

            node[:pivot_x] = 0.0
            node[:pivot_y] = 0.0
            node[:pivot_z] = 0.0

            set_geometry_from_attributes!(node, leaf_refmesh; convention=leaf_convention_with_global_heading)
        elseif organ == "RootSegment"
            root_rank += 1
            length_r = 0.45 * 0.92^(root_rank - 1)
            width_r = 0.05 * 0.9^(root_rank - 1)

            node[:Length] = length_r
            node[:Width] = width_r
            node[:Thickness] = width_r
            node[:XEuler] = 180.0
            node[:YEuler] = 0.0
            node[:ZEuler] = 0.0
            node[:xx] = 0.0
            node[:yy] = 0.0
            node[:zz] = root_depth

            set_geometry_from_attributes!(node, root_refmesh; convention=stem_convention)
            root_depth -= length_r
        end
    end

    mtg
end
```

## 1. Simple Tutorial: Read an MTG File and Reconstruct Geometry

```@example buildgeom
simple_mtg_file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))), "test", "files", "simple_plant.mtg")
mtg_simple = read_mtg(simple_mtg_file)
reconstruct_simple_from_attributes!(mtg_simple, refmesh_stem, refmesh_leaf)
length(descendants(mtg_simple, :geometry; ignore_nothing=true, self=true))
```

```@example buildgeom
plantviz(mtg_simple, color=Dict("Stem" => :tan4, "Leaf" => :forestgreen))
```

## Conventions and Composition Rules

`set_geometry_from_attributes!` uses `GeometryConvention` to map attributes to transformations.

| Concept | Behavior |
| --- | --- |
| Alias resolution | First matching alias is used (`Length`, `length`, `L`, ...). |
| Local angle (`frame=:local`) | Composed in local coordinates: `T = T ∘ R`. |
| Global angle (`frame=:global`) | Applied in world frame around a pivot: `T = recenter(R, pivot) ∘ T`. |
| Pivot | `:origin`, attribute tuple like `(:pivot_x,:pivot_y,:pivot_z)`, or numeric tuple. |
| Translation | Always applied last: `T = Translation(tx,ty,tz) ∘ T`. |
| Missing attributes | Ignored (identity contribution). |

In the simple example, stems use `length_axis=:z`, while leaves use `length_axis=:x` so leaf length follows the blade axis.

## 2. Advanced Tutorial: Build Topology and Geometry from Scratch

```@example buildgeom
mtg_advanced = build_mtg_from_scratch(8, 4)
add_geometry_from_scratch!(mtg_advanced, refmesh_stem, refmesh_leaf, refmesh_root)
length(descendants(mtg_advanced, :geometry; ignore_nothing=true, self=true))
```

```@example buildgeom
plantviz(
    mtg_advanced,
    color=Dict("Stem" => :tan3, "Leaf" => :green4, "Root" => :sienna4),
)
```

This advanced setup uses:

- a dedicated leaf convention with `length_axis=:x`.
- local angles for pitch/roll.
- a global heading angle with an explicit pivot attribute mapping.

## Manual Transform Composition (When Needed)

If you need full control, compose transforms directly with `CoordinateTransformations`:

```julia
manual_t = IdentityTransformation()
manual_t = manual_t ∘ LinearMap(Diagonal([0.08, 0.08, 0.30]))
manual_t = manual_t ∘ LinearMap(RotMatrix(AngleAxis(deg2rad(-35.0), 0.0, 1.0, 0.0)))
manual_t = Translation(0.0, 0.0, 0.5) ∘ manual_t

node[:geometry] = Geometry(ref_mesh=refmesh_stem, transformation=manual_t)
```
