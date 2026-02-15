# Building Plant Models

This page shows a GeometryBasics-first workflow: reference meshes are `GeometryBasics.Mesh` and
node transformations use `CoordinateTransformations`.

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

function prism_mesh(radius=0.5, height=1.0)
    v = [
        PlantGeom.Point3(-radius, -radius, 0.0),
        PlantGeom.Point3(radius, -radius, 0.0),
        PlantGeom.Point3(radius, radius, 0.0),
        PlantGeom.Point3(-radius, radius, 0.0),
        PlantGeom.Point3(-radius, -radius, height),
        PlantGeom.Point3(radius, -radius, height),
        PlantGeom.Point3(radius, radius, height),
        PlantGeom.Point3(-radius, radius, height),
    ]

    f = Tri[
        Tri(1, 2, 3), Tri(1, 3, 4),
        Tri(5, 7, 6), Tri(5, 8, 7),
        Tri(1, 6, 2), Tri(1, 5, 6),
        Tri(2, 7, 3), Tri(2, 6, 7),
        Tri(3, 8, 4), Tri(3, 7, 8),
        Tri(4, 5, 1), Tri(4, 8, 5),
    ]

    GeometryBasics.Mesh(v, f)
end

function leaf_mesh()
    v = [
        PlantGeom.Point3(0.0, -0.05, 0.0),
        PlantGeom.Point3(0.0, 0.05, 0.0),
        PlantGeom.Point3(0.2, 0.0, 0.0),
        PlantGeom.Point3(1.2, 0.0, 0.0),
        PlantGeom.Point3(0.7, -0.5, 0.0),
        PlantGeom.Point3(0.7, 0.5, 0.0),
    ]

    f = Tri[
        Tri(1, 2, 3),
        Tri(3, 5, 4),
        Tri(3, 6, 4),
    ]

    GeometryBasics.Mesh(v, f)
end

refmesh_cylinder = RefMesh("Cylinder", prism_mesh(), RGB(0.5, 0.5, 0.5))
refmesh_leaf = RefMesh("Leaf", leaf_mesh(), RGB(0.1, 0.5, 0.2))

function build_mtg(n_internode=5, n_roots=3)
    mtg = Node(NodeMTG("/", "Plant", 1, 1))

    last_node = mtg
    for i in 1:n_internode
        internode = Node(last_node, NodeMTG(i == 1 ? "/" : "<", "Internode", i, 2))
        Node(internode, NodeMTG("+", "Leaf", i, 2))
        last_node = internode
    end

    last_root = mtg
    for i in 1:n_roots
        last_root = Node(last_root, NodeMTG(i == 1 ? "/" : "<", "RootSegment", i, 2))
    end

    return mtg
end

function add_geometry!(mtg, refmesh_cylinder, refmesh_leaf)
    current_height = 0.0
    internode_width = 0.1
    internode_length = 0.3
    root_width = 0.05
    root_length = 0.5
    root_depth = -0.5
    phyllotaxy = 0.0

    traverse!(mtg) do node
        if symbol(node) == "Internode"
            t = IdentityTransformation()
            t = compose_lr(t, LinearMap(Diagonal([internode_width, internode_width, internode_length])))
            t = compose_lr(t, Translation(0.0, 0.0, current_height))
            node[:geometry] = PlantGeom.Geometry(ref_mesh=refmesh_cylinder, transformation=t)
            current_height += internode_length
            phyllotaxy += pi / 2
        elseif symbol(node) == "Leaf"
            leaf_length = 0.20 + 0.10 * current_height
            leaf_width = 0.5 * leaf_length
            t = IdentityTransformation()
            t = compose_lr(t, LinearMap(Diagonal([leaf_length, leaf_width, 1e-4])))
            t = compose_lr(t, LinearMap(RotY(-pi / 4)))
            t = compose_lr(t, Translation(internode_width / 2, 0.0, current_height))
            t = compose_lr(t, LinearMap(RotZ(phyllotaxy)))
            node[:geometry] = PlantGeom.Geometry(ref_mesh=refmesh_leaf, transformation=t)
        elseif symbol(node) == "RootSegment"
            t = IdentityTransformation()
            t = compose_lr(t, LinearMap(Diagonal([root_width, root_width, root_length])))
            t = compose_lr(t, Translation(0.0, 0.0, root_depth))
            t = compose_lr(t, LinearMap(RotZ(pi)))
            node[:geometry] = PlantGeom.Geometry(ref_mesh=refmesh_cylinder, transformation=t)
            root_depth -= root_length
        end
    end
end

mtg = build_mtg()
add_geometry!(mtg, refmesh_cylinder, refmesh_leaf)
```

## Overview

The recommended workflow is:

1. Define one `RefMesh` per organ type using `GeometryBasics.Mesh`.
2. Build your MTG topology.
3. Attach `Geometry` to each node with a `CoordinateTransformations.Transformation`.

## Create Reference Meshes

```@example buildgeom
refmesh_cylinder
```

## Build an MTG

```@example buildgeom
mtg = build_mtg(4, 2)
add_geometry!(mtg, refmesh_cylinder, refmesh_leaf)
length(descendants(mtg, :geometry; ignore_nothing=true, self=true))
```

## Visualize

```@example buildgeom
plantviz(mtg, color=Dict("Cylinder" => :tan4, "Leaf" => :seagreen3))
```

## Notes

- Internal coordinates are unitless `Float64` values in meters.
- Transform composition is done with `compose_lr(t1, t2)` (left-to-right semantics).
- Use `LinearMap`, `Translation`, and `AffineMap` from `CoordinateTransformations`.
