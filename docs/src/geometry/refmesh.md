# RefMesh

```@setup refmesh
using PlantGeom
using CairoMakie
using GeometryBasics
using Colors

CairoMakie.activate!()

const Tri = GeometryBasics.TriangleFace{Int}

function cylinder_mesh(radius=0.5f0, height=1.0f0)
    c = GeometryBasics.Cylinder(
        Point(0.0, 0.0, 0.0),
        Point(0.0, 0.0, height),
        radius,
    )
    GeometryBasics.mesh(c)
end

cyl = cylinder_mesh()
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
    Point(0.0, 0.0, -0.5),
    Point(1.0, 0.0, -0.5),
    Point(1.0, 0.0, 0.5),
    Point(0.0, 0.0, 0.5),
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
sphere_like = GeometryBasics.mesh(GeometryBasics.Sphere(Point(0.0, 0.0, 0.0), 1.0))

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

## Meshes.jl Interop

PlantGeom's core backend is `GeometryBasics`, but you can build meshes in `Meshes.jl` and convert
them using the optional extension API:

- `to_geometrybasics(mesh::Meshes.SimpleMesh)`
- `to_meshes(mesh::GeometryBasics.Mesh)`
- `to_meshes(ref_mesh::RefMesh)`

### Build a RefMesh from Meshes.jl

```@example refmesh
using Meshes

mesh_meshes = Meshes.CylinderSurface(
    Meshes.Point(0.0, 0.0, 0.0),
    Meshes.Point(0.0, 0.0, 1.0),
    0.2,
) |> Meshes.discretize |> Meshes.simplexify

mesh_gb = to_geometrybasics(mesh_meshes)
ref_from_meshes = RefMesh("cylinder_from_meshes", mesh_gb, RGB(0.3, 0.5, 0.8))

plantviz(ref_from_meshes)
```

### Convert Back to Meshes.jl

```@example refmesh
mesh_back = to_meshes(ref_from_meshes)
(
    nverts_meshes = length(collect(Meshes.vertices(mesh_back))),
    nfaces_meshes = length(collect(Meshes.elements(Meshes.topology(mesh_back)))),
)
```
