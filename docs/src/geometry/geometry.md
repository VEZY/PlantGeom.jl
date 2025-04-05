# Geometry in PlantGeom

## Overview

PlantGeom.jl provides a comprehensive framework for handling 3D geometries in plant architecture models. Geometry representation is a fundamental aspect of plant modeling that enables visualization, spatial analysis, and computation of physical processes like light interception or gas exchange.

## Reference Mesh Design Philosophy

PlantGeom uses a memory-efficient approach based on a key biological observation: many plant organs of the same type (e.g., leaves on a tree) share a common shape that varies only in size, orientation, and position. Instead of storing complete mesh data for each organ, PlantGeom stores:

1. A **reference mesh** that represents the canonical shape of the organ
2. A **transformation matrix** for each instance of the organ that scales, rotates, and positions it appropriately

This approach significantly reduces memory usage and file sizes, especially for complex plant models with thousands of similar organs.

When an organ's shape cannot be easily represented by transforming a reference mesh (e.g., wheat leaves with complex curvature), PlantGeom can fall back to storing the complete mesh directly. In this case, the reference mesh becomes the specific mesh for that organ, and the transformation matrix is the identity (no transformation).

## Geometry Types

In PlantGeom, plant geometries are primarily represented using mesh structures, which can be associated with different components of a plant's architecture stored in a Multi-scale Tree Graph (MTG).

The main geometry types include:

1. **Geometry**: A container type that holds different geometric representations
2. **RefMesh**: A reference mesh that includes metadata and the actual mesh
3. **SimpleMesh**: The underlying mesh data structure (from [Meshes.jl](https://github.com/JuliaGeometry/Meshes.jl))

## Associating Geometry with MTG Components

Geometry is typically associated with specific nodes in an MTG structure using the `:geometry` attribute:

```julia
# Set geometry for a node
node.geometry = Geometry(ref_mesh=some_ref_mesh)

# Check if a node has geometry
has_geometry = haskey(node, :geometry)

# Access the geometry
mesh = node.geometry.ref_mesh.mesh
```

## Common Operations

PlantGeom.jl leverages the functionality of the [Meshes.jl](https://github.com/JuliaGeometry/Meshes.jl) package for core mesh operations. This provides access to a wide range of geometric algorithms and data structures.

It also leverages Rotations.jl and TransformsBase.jl for rotations and other transformations, and for applying and reversing sequential transformation operations. The following operations are commonly performed on geometries:

- **Creating meshes**: Functions for generating basic shapes or reading meshes from files, performed using [Meshes.jl](https://github.com/JuliaGeometry/Meshes.jl), or meshes can be created from other specialized software (*e.g.* Blender)
- **Transforming meshes**: Functions for scaling, rotating (see Rotations.jl and TransformsBase.jl), and translating meshes, again performed using the Meshes.jl package
- **Merging meshes**: Combining multiple meshes into a single mesh (e.g., merging leaf meshes into a single leaf mesh). PlantGeom provides `merge_children_geometry!` for that purpose
- **Analyzing meshes**: Computing properties like area, volume, or bounding boxes, which can be done using the Meshes.jl package

## File Formats

PlantGeom can inport and export in the OPS and OPF formats. It can also read and write meshes to various common file formats using Meshes.jl, including:

- **OBJ**: A common 3D geometry format
- **PLY**: Polygon File Format
- **STL**: Standard Triangle Language
- **OPF**: Open Plant Format (combines MTG structure and geometry)
- ...

The OPF file format specifically leverages the reference mesh concept, storing only the unique reference meshes and the transformation matrices for each node with geometry. This approach significantly reduces file sizes compared to storing complete mesh data for each organ.

## Visualization

Geometries in PlantGeom can be visualized using various Makie.jl backends. For example, we can visualize a plant's geometry using the following code:

```julia
using PlantGeom
using CairoMakie # Could be GLMakie (GPU) or WGLMakie (web) instead

# Load an MTG with geometry
mtg = read_opf("path/to/plant.opf")

# Visualize the geometry
fig = Figure()
ax = Axis3(fig[1, 1])
viz!(ax, mtg)
fig
```

See the [3D recipes](../makie_3d.md) section for more information on visualization options.
