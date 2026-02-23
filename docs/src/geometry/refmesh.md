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
sphere_mesh = GeometryBasics.mesh(GeometryBasics.Sphere(Point(0.0, 0.0, 0.0), 1.0))

sphere_refmesh = RefMesh("sphere", sphere_mesh, RGB(0.7, 0.4, 0.3))
plantviz(sphere_refmesh)
```

### From AMAP-Style Extrusion (Leaflet/Midrib)

PlantGeom includes an AMAP-style extrusion helper (section profile swept along a path),
inspired by AMAPStudio's `ExtrudeData`/`ExtrudedMesh` pattern.

```@example refmesh
leaflet_section = leaflet_midrib_profile(; lamina_angle_deg=40.0, scale=0.5)
leaflet_path = [
    Point(0.0, 0.0, 0.0),
    Point(0.3, 0.0, 0.05),
    Point(0.7, 0.0, 0.10),
    Point(1.0, 0.0, 0.12),
]

leaflet_refmesh = extrude_profile_refmesh(
    "leaflet_extruded",
    leaflet_section,
    leaflet_path;
    widths=[1.0, 0.9, 0.7, 0.45],
    heights=[1.0, 1.0, 0.9, 0.75],
    torsion=true,
    close_section=false,
    cap_ends=false,
    material=RGB(0.15, 0.55, 0.25),
)

plantviz(leaflet_refmesh)
```

### Circular Tube Helper (`makeCircle`-style)

For axis-like organs, use the dedicated circular section helper and tube wrapper:

```@example refmesh
tube_path = [
    Point(0.0, 0.0, 0.0),
    Point(0.3, 0.05, 0.02),
    Point(0.7, 0.08, 0.05),
    Point(1.0, 0.10, 0.08),
]

tube_refmesh = extrude_tube_refmesh(
    "tube_extruded",
    tube_path;
    n_sides=10,
    radius=0.5,
    radii=[1.0, 0.85, 0.7, 0.55], # taper
    torsion=true,
    cap_ends=true,
    material=RGB(0.55, 0.45, 0.35),
)

plantviz(tube_refmesh)
```

### Path Interpolation Helpers (`makePath` / `makeSpline`)

These helpers mirror AMAPStudio utilities and are useful to build smooth centerlines
before extrusion:

```@example refmesh
key_points = [
    Point(0.0, 0.0, 0.0),
    Point(0.2, 0.1, 0.05),
    Point(0.6, 0.15, 0.10),
    Point(1.0, 0.0, 0.15),
]

path_hermite = extrusion_make_path(30, key_points)
path_spline = extrusion_make_spline(30, key_points)

(
    n_path_hermite=length(path_hermite),
    n_path_spline=length(path_spline),
)
```

### Lathe Helpers (`latheGen` / `lathe`)

Build axisymmetric reference meshes directly from radial profiles:

```@example refmesh
z_keys = [0.0, 0.2, 0.6, 1.0]
r_keys = [0.35, 0.25, 0.18, 0.08]

lathe_ref = lathe_refmesh(
    "lathe_profile",
    14,          # around-axis resolution
    40,          # sampling along profile
    z_keys,
    r_keys;
    method=:curve,  # AMAP-like extrema-preserving interpolation
    axis=:x,
    cap_ends=true,
    material=RGB(0.50, 0.38, 0.25),
)

plantviz(lathe_ref)
```

## Procedural RefMeshes and Caching

For reconstruction pipelines, do not rebuild procedural meshes for every node.
Keep the same pattern as classic OPF refmeshes: build once, then reuse with node transforms.

Use the same constructor with an optional `cache` dictionary:

```@example refmesh
cache = Dict{Any,Any}()

shaft_ref = extrude_tube_refmesh(
    "shaft_r04_l10",
    [Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0)];
    cache=cache,
    n_sides=12,
    radius=0.4,
    cap_ends=true,
)

# same parameters => same RefMesh instance reused
shaft_ref_again = extrude_tube_refmesh(
    "shaft_r04_l10",
    [Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0)];
    cache=cache,
    n_sides=12,
    radius=0.4,
    cap_ends=true,
)

shaft_ref === shaft_ref_again
```

Recommended integration rule:

- when many nodes share the same procedural shape parameters: use cached constructors and reuse the `RefMesh`
- when each node has unique geometry (for example organ-specific measured profile): build one `RefMesh` per unique parameter set
- keep node placement in `Geometry` transforms (`translation/rotation/scale`) as usual

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
