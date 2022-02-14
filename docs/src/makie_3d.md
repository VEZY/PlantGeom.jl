# `Makie.jl` recipes

```@example 1
using JSServe
Page(exportable=true, offline=true)
```

## 3D plots (meshes)

Here comes the fun part! We can make 3D representations of the plants based on the geometry of each of its nodes.

If you read your MTG from an OPF file, the 3D geometry should already be computed.

```@example 1
using PlantGeom, WGLMakie
opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf"))
viz(opf, color = Dict(1 => :burlywood4, 2 => :springgreen4))
```
