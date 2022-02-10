# `Makie.jl` recipes

```@setup usepkg
using PlantGeom
using GLMakie
opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf"))
```

## Diagram

We can make a diagram of the MTG graph using the [`diagram`](@ref) function:

```@example usepkg
using PlantGeom, GLMakie

opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf"))

diagram(opf)
```

We can change the color of the nodes:

```@example usepkg
diagram(opf, color = :red)
```

Or even coloring based on attributes, *e.g.* using the nodes Z coordinates:

```@example usepkg
diagram(opf, color = :ZZ)
```

## 3D plots (meshes)

Here comes the fun part! We can make 3D representations of the plants based on the geometry of each of its nodes.

If you read your MTG from an OPF file, the 3D geometry should already be computed.
