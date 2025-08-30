# Architecture Overview

This package bridges Plant MTGs with meshes and visualization.

```text
OPF/OPS files ──► read_opf/read_ops ──► MTG (MultiScaleTreeGraph)
                                  │
                                  ▼
                         Reference Meshes (RefMesh)
                                  │
                                  ▼
              Geometry (ref_mesh + transform + cached mesh)
                                  │
                   refmesh_to_mesh! / transform_mesh!
                                  │
                                  ▼
                        Meshes.SimpleMesh geometry
                                  │
                                  ▼
            plantviz (Makie recipe) ──► Makie Figure/Axis
```

- Core types: `RefMesh` stores template geometry; `Geometry` attaches a `ref_mesh`, a transform (`Translate`, `Rotate`, `Scale`, `Affine`, or `SequentialTransform`), and an optional cached mesh to an MTG node attribute `:geometry`.
- IO: `read_opf`/`read_ops` populate MTG nodes and scene transforms; `write_opf`/`write_ops` serialize meshes and transforms back to disk.
- Computation: meshes are computed lazily; call `refmesh_to_mesh!` to materialize or `transform_mesh!` to apply composed transforms. Matrix generation uses `get_transformation_matrix`.
- Visualization: `plantviz` dispatches to Makie recipes in `ext/makie_recipes/`, mapping colors from attributes or user dictionaries via `get_color`/`get_colormap`.

Minimal example

```julia
using PlantGeom
opf = read_opf("test/files/simple_plant.opf")
refmesh_to_mesh!(opf)              # materialize per-node meshes
fig, ax, plt = plantviz(opf)       # visualize
```
