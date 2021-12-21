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

Plot the plant geometry:

```julia
viz(opf)
```
