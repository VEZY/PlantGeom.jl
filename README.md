# PlantGeom.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/PlantGeom.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/PlantGeom.jl/dev)
[![Build Status](https://github.com/VEZY/PlantGeom.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/VEZY/PlantGeom.jl/actions/workflows/CI.yml?query=branch%3Amain)

[PlantGeom](https://github.com/VEZY/PlantGeom.jl), a package for everything 3D in plants.

## Introduction

The package is designed around [MultiScaleTreeGraph](https://github.com/VEZY/MultiScaleTreeGraph.jl) that serves as the basic structure for the plant topology and attributes.

The package provides different functionalities, the main ones being:

- IO for the OPF file format (see `read_opf` and `write_opf`);
- plotting using `viz` and `viz!`, optionally using coloring by attribute;
- mesh transformations using `transform_mesh!`

Note that `:geometry` is a reserved attribute in nodes (*e.g.* organs) used for the 3D geometry. It is stored as a special structure (`geometry`).

## Example usage

Read an example OPF:

```julia
using PlantGeom, MultiScaleTreeGraph

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
mtg = read_opf(file)
```

Plot the plant geometry:

```julia
using GLMakie # Choose a Makie backend here.
viz(mtg)
```

`viz` search for the `:geometry` attribute in the MTG nodes, and computes the meshes using the reference meshes and the transformation matrices to plot the 3d geometry of the plants.

Colour by attribute, *e.g.* using the mesh max Z coordinates:

```julia
transform!(mtg, refmesh_to_mesh!, zmax => :z_max, ignore_nothing = true)
viz(mtg, color = :z_max)
```

By design the 3D geometry of each node is stored in the `:geometry` attribute. It stores a reference mesh, a transformation matrix, and the resulting mesh. The resulting mesh is computed lazily, meaning it is computed only the first time it is needed. To compute it explicitly, you can use `refmesh_to_mesh!` (like above):

```julia
transform!(mtg, refmesh_to_mesh!)
```

## Roadmap

- [x] Add `read_opf()`
- [x] Add `write_opf()`.
- [x] Use pointers to ref meshes instead of an index. It will be more simple then.
- [ ] Add `read_ops()`
- [x] Add recipe for MTG diagram (no geometry )
- [ ] Use Primitives from Meshes as reference meshes:
  - [x] I added cylinder, but remove it whenever it is available from Meshes.jl.
- [ ] Import reference meshes from disk (e.g. export from blender). This is done for the cylinder. Document it.
- [ ] Add a ref mesh for wood
- [ ] Add a ref mesh for a leaf
- [ ] Add tutorials:
  - [x] How to plot with Plots.jl
  - [x] How to plot with Makie.jl
  - [ ] How to build a geometry using attributes and reference meshes
  - [ ] How to build a plant + geometry manually and recursively
- [ ] Manage different kind of information into an MTG:
  - [ ] Mesh for the nodes
  - [ ] Reference meshes + transformation matrix (e.g. from OPF)
  - [ ] Reference meshes + Length and/or Width/diameter for scaling. If only Length, scale the whole mesh by a factor, if Length + Width, scale accordingly
- [ ] Remove coffee.opf from tests and add PlantBiophysics as a dependency instead. It will make PlantGeom much lighter.
- [x] Improve the OPF parser using e.g. our own XML parser. See <https://github.com/ordovician/PLists.jl> for an example pure Julia XML parser, and the corresponding [blogpost here](https://blog.devgenius.io/how-to-easily-write-an-xml-parser-in-julia-7cd02f19d8c6). Make the reading in parallel ? For reference, reading a 80Mo OPF takes 8Go of memory and 4.5 minutes... -> The issue came from SVectors that took forever to be allocated. I replaced them by normal vectors. It is much faster now (~11s on my computer).
- [ ] Make read_opf even faster (we should aim for e.g. 2-3s for an 80Mo OPF (largest file we have). We can make it parallel, but I think we can improve some things first (e.g. using structs instead of Dicts everywhere).
- [ ] Improve the OPF writer similarly. It takes forever writing to disk.
- [ ] Add a section about the OPF format.
- [ ] Fix the example simple OPF -> use one cylinder only, fix the scales of each node.
- [ ] Fix the coffee OPF -> scales are wrong (Metamer = 6 -> 3, Leaf = 2 -> 3) + Fix the MTG accordingly
- [ ] Add tests using both simple_plant.opf and simple_plant.mtg to make sure both work the same way.
- [ ] Fix the OPF writer: follow nodes are placed as siblings not children.
- [ ] Make it compatible with <https://github.com/JuliaGeometry/GeometryBasics.jl>
- [ ] Compute the vertex normals properly when writting the OPF to disk
- [ ] Use the MakieCore package instead of Makie.jl to avoid the heavy dependencies of Makie.jl
