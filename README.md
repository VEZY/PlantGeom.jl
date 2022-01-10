# PlantGeom.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://VEZY.github.io/PlantGeom.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://VEZY.github.io/PlantGeom.jl/dev)
[![Build Status](https://github.com/VEZY/PlantGeom.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/VEZY/PlantGeom.jl/actions/workflows/CI.yml?query=branch%3Amain)

PlantGeom.jl helps compute the geometry of plants and beautiful plots.

## Example usage

Read an example OPF:

```julia
using PlantGeom, MultiScaleTreeGraph

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
```

Compute the 3D geometry:

```julia
ref_meshes = get_ref_meshes(opf)
transform!(opf, (node -> refmesh_to_mesh(node, ref_meshes)) => :mesh)
```

Plot the plant geometry using the reference meshes:

```julia
viz(opf)
```

`viz` search for the `:mesh` attribute in the MTG given as the first argument, and use them to plot the 3d geometry of the plants.

Colour by attribute, *e.g.* using the mesh max Z coordinates:

```julia
transform!(opf, :mesh => (x -> maximum([i.coords[3] for i in x.points])) => :z_max, ignore_nothing = true)
viz(opf, color = :z_max)
```

## Roadmap

- [x] Add `read_opf()`
- [x] Add `write_opf()`.
- [x] Use pointers to ref meshes instead of an index. It will be more simple then.
- [ ] Add `read_ops()`
- [ ] Add recipe for simple MTG without any geometry (and remove this plot from MultiScaleTreeGraph)
- [ ] Manage different degree of information into an MTG:
  - [ ] Mesh for the nodes
  - [ ] Reference meshes + transformation matrix (e.g. from OPF)
  - [ ] Reference meshes + Length and/or Width/diameter for scaling. If only Length, scale the whole mesh by a factor, if Length + Width, scale accordingly
  - [ ] No dimensions at all -> plot MTG representation.
  - [ ] Add argument to control this ? E.g.: type = "mtg" or type = "3d"
