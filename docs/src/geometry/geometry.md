# Geometry Concepts in PlantGeom

## Overview

PlantGeom provides a framework for representing, manipulating, and visualizing 3D plant architecture. This page introduces the key concepts behind PlantGeom's approach to geometry handling.

## Reference Mesh Design Philosophy

Most plants contain many similar organs - think of hundreds of leaves on a tree that share the same basic shape but differ in size and orientation. PlantGeom leverages this biological pattern through its **reference mesh** approach:

1. Define a single **reference mesh** for each organ type (e.g., a generic leaf shape)
2. Apply **transformations** (scaling, rotation, translation) to position each instance

This approach offers significant benefits:

- **Memory efficiency**: Store one mesh instead of hundreds of copies
- **Smaller file sizes**: OPF files store only unique reference meshes plus transformations
- **Performance**: Operations can be applied to reference meshes once rather than to many instances

For highly specialized shapes that can't be derived from a reference (like wheat leaves with complex curvatures), PlantGeom can still use direct mesh representations.

## Key Components

PlantGeom's geometry system consists of three main components:

1. **RefMesh**: A reference mesh with a unique identifier and the mesh data
2. **Geometry**: A container that links a RefMesh to a node and stores transformation information
3. **Transformations**: Operations that scale, rotate, and position instances of reference meshes

## MTG Integration

Geometries in PlantGeom are attached to nodes in a Multi-scale Tree Graph (MTG) that represents plant topology:

```julia
# Attaching geometry to an MTG node
node.geometry = Geometry(ref_mesh=some_ref_mesh, transformation=some_transformation)
```

## Documentation Structure

To learn more about PlantGeom's geometry features:

- **Reference Meshes**: Learn how to create and work with reference meshes
- **Building Plant Models**: Step-by-step guide to constructing complete plant geometries
- **Merging Meshes**: Tools for combining geometries at different scales

## File Format Support

PlantGeom works with several file formats:

- **OPF**: Open Plant Format - combines MTG structure and geometry efficiently
- **OBJ/PLY/STL**: Common 3D mesh formats

## Basic Usage Example

```julia
using PlantGeom
using CairoMakie

# Load a plant model with geometry
mtg = read_opf("path/to/plant.opf")

# Visualize
fig = Figure()
ax = Axis3(fig[1, 1])
viz!(ax, mtg)
fig
```

For more visualization options, see the [3D recipes](../makie_3d.md) section.
