# Architecture Overview

This package bridges Plant MTGs with meshes and high‑performance visualization.

```text
OPF/OPS files ──► read_opf/read_ops ──► MTG (MultiScaleTreeGraph)
                                  │
                                  ▼
                         Reference Meshes (RefMesh)
                                  │
                                  ▼
                    Geometry (ref_mesh + transform)
                                  │
                    (lazy) refmesh_to_mesh! per node
                                  │
                                  ▼
            Merge all meshes into a single Meshes.SimpleMesh geometry
                                  │
                                  ▼
             plantviz (Makie recipe) ──► Makie Figure/Axis
```

- Core types: `RefMesh` stores template geometry; `Geometry` attaches a `ref_mesh`, a transform (`Translate`, `Rotate`, `Scale`, `Affine`, or `SequentialTransform`), and an optional cached mesh to an MTG node attribute `:geometry`.
- IO: `read_opf`/`read_ops` populate MTG nodes and scene transforms; `write_opf`/`write_ops` serialize meshes and transforms back to disk.
- Computation: meshes are computed lazily; call `refmesh_to_mesh!` to materialize or `transform_mesh!` to apply composed transforms. Matrix generation uses `get_transformation_matrix`. At render time, node meshes are merged to a single `SimpleMesh`.
- Visualization: `plantviz` builds on Makie’s ComputeGraph. It maps colors from attributes or user dictionaries via `get_mtg_color`/`get_color`/`get_colormap`, wires them as compute nodes with `map!`, and renders the merged mesh once.

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
Per-node color values (or per-refmesh/per-vertex inputs)
          │             ┌─────────────────────────────────────────┐
          ├────────────►│ Cache: UUIDs-based attribute on MTG     │
          │             │ (e.g., :_cache_<hash>) holds Observables│
          ▼             └─────────────────────────────────────────┘
 Makie plot attributes (colormap, colorrange, color per vertex)
          │
          ▼
        plantviz recipe renders via Meshes/Makie
```

- Inputs: single color, `Dict("RefMeshName" => color)`, attribute symbol (e.g., `:z_max`), or per-vertex arrays. A vector of colors/symbols per node is also supported; it expands to per-face colors using the `face2node` mapping of the merged mesh.
- Mapping: `get_colormap` resolves a `ColorScheme`; `get_color_range` derives or validates ranges; `get_color` maps values to colors.
- Caching:
  - Per-node color caches (UUID-derived Observables) for interactive updates when plotting per-node geometry.
  - Scene cache on the root (`:_scene_cache`) as a single-entry NamedTuple `(hash, mesh, face2node)`. The `hash` encodes the scene version and relevant options (filters). Invalidate with `bump_scene_version!(mtg)`.

### Rendering Model (Merged by Default)

- Build: traverses selected nodes, transforms ref meshes, materializes node meshes if needed, and merges them into one `SimpleMesh` for rendering. The merge is performed in a single pass for performance.
- Colors: computes a single per-vertex color array and passes it to Makie. Attribute colors honor `colormap` and `colorrange`; dictionary inputs by refmesh are supported; per-vertex dictionaries pass through directly.
- Mapping: `face2node` is stored alongside the merged mesh in `:_scene_cache` to map triangles back to node IDs. This enables expanding per-node color vectors to per-face arrays.
- Use: `plantviz(opf, color=:z_max)`; invalidate cache after geometry/attribute changes via `bump_scene_version!(opf)`. The merged mesh and `face2node` are reused across color updates.

## Key Components

- `build_merged_mesh_with_map(mtg; ...)`: collects selected node meshes and returns `(merged::SimpleMesh, face2node::Vector{Int})`. The `face2node` array maps each element of the merged mesh back to its originating node id.
- Scene cache helpers:
  - `scene_version`, `bump_scene_version!`: version the scene to invalidate cache.
  - `scene_cache_key`: builds a stable key for the current selection/options.
  - `get_cached_scene`, `set_cached_scene!`: retrieve/store a single cached scene `(hash, mesh, face2node)` on the MTG root.
- PlantViz recipe (Makie): defines attributes (`color`, `colormap`, `colorrange`, etc.) and derives compute nodes with `map!` (`:colorant`, `:colormap_resolved`, `:colorrange_resolved`, `:index_resolved`). The plot calls into a helper that computes or retrieves the merged scene and computes vertex colors as needed.

## Performance Notes

- Merging: performed in one pass; avoid repeated pairwise merges. Connectivity indices are reindexed with a running vertex offset.
- face2node: built with a single preallocated vector, filling by contiguous slices per node to minimize allocations.
- Colors: computed once per render and are not cached in the scene cache; only the merged mesh and face2node are cached to reduce invalidation churn.
