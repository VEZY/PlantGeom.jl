# PlantGeom.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/PlantGeom.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/PlantGeom.jl/dev)
[![Build Status](https://github.com/VEZY/PlantGeom.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/VEZY/PlantGeom.jl/actions/workflows/CI.yml?query=branch%3Amain)

[PlantGeom](https://github.com/VEZY/PlantGeom.jl), a package for everything 3D in plants.

## Introduction

The package is designed around [MultiScaleTreeGraph](https://github.com/VEZY/MultiScaleTreeGraph.jl) that serves as the basic structure for the plant topology and attributes.


Note that `:geometry` is a reserved attribute used to hold each node (*e.g.* organ) 3D geometry as a special structure ([`geometry`](@ref)).

The package provides different functionalities, the main ones being:

- IO for the OPF file format (see [`read_opf`](@ref) and [`write_opf`](@ref));
- plotting using [`viz`](@ref) and [`viz!`](@ref), optionally using colouring by attribute;
- mesh transformations using [`transform_mesh!`](@ref)

## Example usage

Read an example OPF:

```julia
using PlantGeom, MultiScaleTreeGraph

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
```

Plot the plant geometry:

```julia
viz(opf)
```

`viz` search for the `:geometry` attribute in the MTG nodes, and computes the meshes using the reference meshes and the transformation matrices to plot the 3d geometry of the plants.

Colour by attribute, *e.g.* using the mesh max Z coordinates:

```julia
transform!(opf, zmax => :z_max, ignore_nothing = true)
viz(opf, color = :z_max)
```

By design the 3D geometry of each node is stored in the `:geometry` attribute. It holds a reference mesh, a transformation matrix, and the resulting mesh. The resulting mesh is computed lazily, meaning it is computed only the first time it is needed. To compute it explicitly, you can use `refmesh_to_mesh!`:

```julia
transform!(opf, refmesh_to_mesh!)
```

## Roadmap

- [x] Add `read_opf()`
- [x] Add `write_opf()`.
- [x] Use pointers to ref meshes instead of an index. It will be more simple then.
- [ ] Add `read_ops()`
- [ ] Add recipe for simple MTG without any geometry (and remove this plot from MultiScaleTreeGraph)
- [ ] Use Primitives from Meshes as reference meshes.
- [ ] Import reference meshes from disk (e.g. export from blender)
- [ ] Add a ref mesh for wood
- [ ] Add a ref mesh for a leaf
- [ ] Add tutorials
- [ ] Manage different degrees of information into an MTG:
  - [ ] Mesh for the nodes
  - [ ] Reference meshes + transformation matrix (e.g. from OPF)
  - [ ] Reference meshes + Length and/or Width/diameter for scaling. If only Length, scale the whole mesh by a factor, if Length + Width, scale accordingly
  - [ ] No dimensions at all -> plot MTG representation.
  - [ ] Add argument to control this ? E.g.: type = "mtg" or type = "3d"
