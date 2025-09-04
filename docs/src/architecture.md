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
- Caching: two layers exist:
  - Per-node color caches (UUID-derived Observables) for interactive updates.
  - Scene cache on the root (`:_scene_cache`) as a single-entry NamedTuple with `(hash, mesh, face2node)`. The `hash` encodes the scene version and relevant plotting options. Invalidate with `bump_scene_version!(mtg)`.

### Merged Mode (Performance)

- Build: traverses nodes, transforms ref meshes, and merges using `Meshes.merge` into one `SimpleMesh`.
- Colors: computes per-vertex colors once and passes a single color array to Makie.
- Mapping: `face2node` is stored alongside the merged mesh in `:_scene_cache` to map triangles back to node IDs.
- Use: `plantviz(opf; merged=true, color=:z_max)`; invalidate cache after geometry/attribute changes via `bump_scene_version!(opf)`.
