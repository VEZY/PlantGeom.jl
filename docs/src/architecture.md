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

## Color Mapping & Caching

```text
User input to plantviz(color=..., colormap=..., colorrange=...)
          │
          ▼
  get_mtg_color / get_ref_meshes_color   get_colormap
          │                                │
          ▼                                ▼
      get_color_range ◄──────────── optional user colorrange
          │
          ▼
Per-node/mesh color values (may be Observables)
          │             ┌─────────────────────────────────────────┐
          ├────────────►│ Cache: UUIDs-based attribute on MTG    │
          │             │ (e.g., :_cache_<hash>) holds Observables│
          ▼             └─────────────────────────────────────────┘
 Makie plot attributes (colormap, colorrange, color per segment)
          │
          ▼
        plantviz recipe renders via Meshes/Makie
```

- Inputs: single color, `Dict("RefMeshName" => color)`, attribute symbol (e.g., `:z_max`), or per-vertex arrays.
- Mapping: `get_colormap` resolves a `ColorScheme`; `get_color_range` derives or validates ranges; `get_color` maps values to colors.
- Caching: color values may be wrapped in Observables and stored on nodes with a UUID-derived key to enable interactivity without recomputing.
