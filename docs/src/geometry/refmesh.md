# RefMesh

```@setup refmesh
using PlantGeom
using CairoMakie
using GeometryBasics
using Colors

CairoMakie.activate!()

const Tri = GeometryBasics.TriangleFace{Int}

function cylinder_like_mesh(radius=0.5, height=1.0)
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

cyl = cylinder_like_mesh()
cylinder_refmesh = RefMesh("cylinder_1", cyl)
```

## Overview

`RefMesh` is PlantGeom's reference geometry container. It stores one canonical mesh plus metadata
(material, normals, optional UVs). Node geometries then reuse the same reference mesh with per-node
transformations.

## Why Reference Meshes?

Instead of duplicating a full mesh for every organ instance, PlantGeom stores one mesh per organ
kind and transforms it at runtime. This is memory-efficient and matches OPF semantics.

## Structure

A `RefMesh` contains:

- `name`: reference mesh name.
- `mesh`: `GeometryBasics.Mesh` (triangular mesh).
- `normals`, `texture_coords`, `material`, `taper` metadata.

## Create a RefMesh

### From Vertices and Faces

```@example refmesh
mesh_vertices = [
    PlantGeom.Point3(0.0, 0.0, -0.5),
    PlantGeom.Point3(1.0, 0.0, -0.5),
    PlantGeom.Point3(1.0, 0.0, 0.5),
    PlantGeom.Point3(0.0, 0.0, 0.5),
]

mesh_faces = [
    Tri(1, 2, 3),
    Tri(1, 3, 4),
]

plane = GeometryBasics.Mesh(mesh_vertices, mesh_faces)
ref_mesh = RefMesh("plane", plane, RGB(0.2, 0.7, 0.3))
plantviz(ref_mesh)
```

### From a Generated Mesh

```@example refmesh
sphere_like = GeometryBasics.Mesh(
    [
        PlantGeom.Point3(0.0, 0.0, 1.0),
        PlantGeom.Point3(1.0, 0.0, 0.0),
        PlantGeom.Point3(0.0, 1.0, 0.0),
        PlantGeom.Point3(-1.0, 0.0, 0.0),
        PlantGeom.Point3(0.0, -1.0, 0.0),
        PlantGeom.Point3(0.0, 0.0, -1.0),
    ],
    Tri[
        Tri(1, 2, 3), Tri(1, 3, 4), Tri(1, 4, 5), Tri(1, 5, 2),
        Tri(6, 3, 2), Tri(6, 4, 3), Tri(6, 5, 4), Tri(6, 2, 5),
    ],
)

sphere_refmesh = RefMesh("sphere_like", sphere_like, RGB(0.7, 0.4, 0.3))
plantviz(sphere_refmesh)
```

### Cylinder-like Primitive

```@example refmesh
plantviz(cylinder_refmesh)
```

## Access Properties

```@example refmesh
(name=cylinder_refmesh.name,
 nvertices=nvertices(cylinder_refmesh),
 nelements=nelements(cylinder_refmesh))
```
