```@meta
CurrentModule = PlantGeom
```

# PlantGeom

Documentation for [PlantGeom](https://github.com/VEZY/PlantGeom.jl), a package for plant 3D geometry
on top of [MultiScaleTreeGraph](https://github.com/VEZY/MultiScaleTreeGraph.jl).

Main capabilities:

- OPF/OPS IO (`read_opf`, `write_opf`, `read_ops`, `write_ops`)
- 3D plotting with `plantviz` / `plantviz!`
- Geometry transformations through `Geometry` + `CoordinateTransformations`

PlantGeom reserves the `:geometry` attribute on nodes.

```@setup home
using CairoMakie
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics

CairoMakie.activate!()

opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf"))

transform!(opf, zmax => :z_node, ignore_nothing=true)
```

## Quick Example

```@example home
f = Figure()
ax1 = Axis(f[1, 1], title="MTG diagram")
ax2 = Axis3(f[1, 2], aspect=:data, title="3D mesh")

diagram!(ax1, opf, color=:z_node)
hidedecorations!(ax1)

plantviz!(ax2, opf, color=:seagreen3)

f
```

## Reproduce in a Script

```julia
using CairoMakie
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics

opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf"))

transform!(opf, zmax => :z_node, ignore_nothing=true)

f = Figure()
ax1 = Axis(f[1, 1], title="MTG diagram")
ax2 = Axis3(f[1, 2], aspect=:data, title="3D mesh")

diagram!(ax1, opf, color=:z_node)
plantviz!(ax2, opf, color=:seagreen3)

f
```
