# RefMesh

```@setup refmesh
using PlantGeom, CairoMakie, Meshes
using Bonito
Page()
CairoMakie.activate!()
cyl = Meshes.CylinderSurface((0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 0.5) |> Meshes.discretize |> Meshes.simplexify
cylinder_refmesh = RefMesh("cylinder_1", cyl)
```

## Overview

`RefMesh` is a core type in PlantGeom.jl that represents a reference mesh. It combines a mesh geometry with metadata such as an identifier, making it suitable for use in plant architecture models.

## Reference Mesh Concept

PlantGeom implements an efficient approach to representing plant geometry based on the insight that most organs of the same type (e.g., leaves, internodes) share a common shape that varies only in size, orientation, and position. Instead of storing complete, unique mesh data for each organ instance, PlantGeom uses:

1. A **reference mesh** that defines the canonical shape of the organ type
2. **Transformation matrices** for each instance that scale, rotate, and translate this reference into the correct position

This method is especially powerful for plants like trees with thousands of similar leaves, where storing a unique mesh for each leaf would consume enormous amounts of memory.

### Benefits of the Reference Mesh Approach

- **Memory efficiency**: Only one mesh is stored for many organs with the same shape
- **Smaller file sizes**: The OPF file format leverages this concept, storing only unique reference meshes plus transformation matrices
- **Computational optimization**: Operations can be applied to one mesh rather than thousands of individual copies

### Handling Special Cases

For organs with unique shapes that cannot be easily derived from scaling and transforming a reference (such as wheat leaves with complex curvature angles), PlantGeom accommodates this by:

1. Using the actual specific mesh as the reference mesh
2. Using an identity transformation matrix (no transformation)

This flexibility ensures that PlantGeom can represent both regular, repeating structures and unique, complex shapes within the same model.

## Structure

A `RefMesh` contains:

- `id`: A string identifier for the mesh
- `mesh`: The actual mesh data structure (typically a `SimpleMesh` from Meshes.jl)

!!! warning
    The RefMesh is usually oriented with its length along the X direction, its width along the Y direction, and its height along the Z direction. This orientation is important for ensuring that transformations and visualizations behave as expected. You can still orient the mesh in any direction, but you'll have to handle the transformations appropriately.

## Creating a RefMesh

There are several ways to create a `RefMesh`.

### From an Existing Mesh

You can create a `RefMesh` from an existing mesh object. This is useful when you have a mesh already defined and want to wrap it in a `RefMesh` for use in PlantGeom:

```julia
using PlantGeom
using GeoIO

# Read a mesh from a file: 
geotable = GeoIO.load("flower.ply")
# Create a RefMesh from an existing mesh:
ref_mesh = RefMesh("flower", geotable.geometry)
```

You can find an example for the trunk snags in [VPalm here](https://github.com/PalmStudio/VPalm.jl/blob/02f037beb816f76bfdae1eae60f740014ed0e398/src/geometry/snag.jl).

### From Vertices and Faces

You can manually create a mesh from vertices and faces first, and pass it to the `RefMesh`. This is useful for defining simple shapes or custom meshes.

For example we can creata a plane mesh with 4 vertices and 2 triangles:

```@example refmesh
using Meshes
mesh_vertices = [
    Meshes.Point(0.0, 0.0, -0.5),  # Left bottom
    Meshes.Point(1.0, 0.0, -0.5),   # Right bottom
    Meshes.Point(1.0, 0.0, 0.5),   # Right top
    Meshes.Point(0.0, 0.0, 0.5)   # Left top
]

# Create triangular faces
# Two triangles to form the rectangle
mesh_faces = [
    Meshes.connect((1, 2, 3), Meshes.Triangle),
    Meshes.connect((1, 3, 4), Meshes.Triangle)
]

# Create the mesh
mesh = Meshes.SimpleMesh(mesh_vertices, mesh_faces)

ref_mesh = RefMesh("plane", mesh)

plantviz(ref_mesh)
```

This is used to create simple leaflets elements in [VPalm](https://github.com/PalmStudio/VPalm.jl/blob/896a25fba8810adb2b893c186223eb73cc94202d/src/geometry/plane.jl).

### From Primitive Shapes

You can also create a `RefMesh` directly from primitive shapes like spheres, cylinders, or cones. This is useful for quickly generating common geometric forms. The only thing to remember is to use the `discretize` function to create a mesh from the primitive shape, and then use the `simplexify` function to convert it to a triangulated mesh.

To create a sphere:

```@example refmesh
using Meshes
sphere_mesh = Meshes.Sphere((0.0, 0.0, 0.0), 1.0) |> Meshes.discretize |> Meshes.simplexify
sphere_refmesh = RefMesh("sphere_1", sphere_mesh)
plantviz(sphere_refmesh)
```

Or a cylinder:

```@example refmesh
cyl = Meshes.CylinderSurface((0.0, 0.0, 0.0), (0.0, 0.0, 1.0), 0.5) |> Meshes.discretize |> Meshes.simplexify
cylinder_refmesh = RefMesh("cylinder_1", cyl)

plantviz(cylinder_refmesh)
```

## Working with RefMesh

### Accessing Properties

```julia
# Get the ID
name = cylinder_refmesh.name

# Get the underlying reference mesh
mesh = cylinder_refmesh.mesh

# Or any other property of the mesh:
fieldnames(typeof(cylinder_refmesh))

# Get vertices
verts = vertices(cylinder_refmesh.mesh)

# Get faces
faces = Meshes.topology(cylinder_refmesh.mesh)
```
