# Explicit Coordinates: Which Option Should I Use?

!!! info "Page Info"
    - **Audience:** Beginner to Intermediate
    - **Prerequisites:** [`MTG Reconstruction Tutorial`](build_and_simulate_3d_plants/reconstructing_an_mtg/amap_quickstart.md)
    - **Time:** 8 minutes
    - **Output:** Clear choice of explicit-coordinate option in `AmapReconstructionOptions`

This page is about **one specific reconstruction option**:

```julia
AmapReconstructionOptions(explicit_coordinate_mode=...)
```

You pass this option to reconstruction like this:

```julia
set_geometry_from_attributes!(
    mtg,
    prototypes;
    convention=default_amap_geometry_convention(),
    amap_options=AmapReconstructionOptions(explicit_coordinate_mode=:topology_default),
)
```

Use this page **only if your MTG contains explicit coordinates** such as `XX`, `YY`, `ZZ`, `EndX`, `EndY`, `EndZ`.

If your MTG only contains sizes and angles (`Length`, `Width`, `YInsertionAngle`, `XEuler`, ...), you do **not** need this page yet.  
Stay with the default reconstruction from [`MTG Reconstruction Tutorial`](build_and_simulate_3d_plants/reconstructing_an_mtg/amap_quickstart.md).

## What This Option Controls

`explicit_coordinate_mode` tells PlantGeom what to do when node coordinates are present in the MTG.

Without explicit coordinates:
- node positions are reconstructed from topology (`:<`, `:+`, `:/`) and attributes such as `Offset`, insertion angles, and Euler angles.

With explicit coordinates:
- PlantGeom must decide whether these coordinates:
  - simply place the current node,
  - rewire the previous segment,
  - or require a full start/end segment definition.

That is exactly what `explicit_coordinate_mode` chooses.

## Quick Chooser

| Your MTG contains | You want | Use in `AmapReconstructionOptions(...)` |
| --- | --- | --- |
| No `XX/YY/ZZ` | Standard MTG reconstruction from topology + angles | do nothing; default is fine |
| `XX/YY/ZZ`, but no `EndX/EndY/EndZ` | Coordinates place the node base, but the node stays a visible segment | `explicit_coordinate_mode=:topology_default` |
| `XX/YY/ZZ`, but no `EndX/EndY/EndZ` | Coordinates should act as control points that bend/rewire the previous segment | `explicit_coordinate_mode=:explicit_rewire_previous` |
| `XX/YY/ZZ` and complete `EndX/EndY/EndZ` | Each explicit node should be reconstructed from a known start and end | `explicit_coordinate_mode=:explicit_start_end_required` |

## The Three Modes in Plain Language

### 1. `:topology_default`

Use this when:
- you have some explicit base coordinates,
- but you still want the current node to be a normal visible segment,
- and you still want angles/topology to define direction when end coordinates are missing.

Mental model:
- `XX/YY/ZZ` says where the node starts
- the rest of the geometry is still reconstructed normally

This is the safest choice for most users.

```julia
opts = AmapReconstructionOptions(explicit_coordinate_mode=:topology_default)
```

### 2. `:explicit_rewire_previous`

Use this when:
- your explicit coordinates come from a topology editor or manual control-point workflow,
- and a node position is intended to redirect the **previous** segment.

Mental model:
- explicit nodes are used as control points
- the previous segment is rewired toward that point
- the current explicit node becomes a point-anchor rather than a normal visible cylinder

This is more specialized. Use it only if you know your data was produced that way.

```julia
opts = AmapReconstructionOptions(explicit_coordinate_mode=:explicit_rewire_previous)
```

### 3. `:explicit_start_end_required`

Use this when:
- you trust your explicit coordinates fully,
- and your MTG stores both node start and node end coordinates.

Mental model:
- `XX/YY/ZZ` gives the start
- `EndX/EndY/EndZ` gives the end
- PlantGeom builds the segment directly from those two points

If end coordinates are missing, the node geometry is omitted on purpose.

```julia
opts = AmapReconstructionOptions(explicit_coordinate_mode=:explicit_start_end_required)
```

## Recommended Starting Point

Start with:

```julia
opts = AmapReconstructionOptions(explicit_coordinate_mode=:topology_default)
```

Then switch only if your data clearly matches one of these cases:
- topology-editor style control points: `:explicit_rewire_previous`
- complete and trusted start/end coordinates: `:explicit_start_end_required`

## Minimal Code Patterns

```julia
using PlantGeom

opts = AmapReconstructionOptions(
    explicit_coordinate_mode=:topology_default,
)

set_geometry_from_attributes!(
    mtg,
    prototypes;
    convention=default_amap_geometry_convention(),
    amap_options=opts,
)
```

```julia
opts = AmapReconstructionOptions(
    explicit_coordinate_mode=:explicit_rewire_previous,
)
```

```julia
opts = AmapReconstructionOptions(
    explicit_coordinate_mode=:explicit_start_end_required,
)
```

## What To Read Next

- If you want to know **which MTG columns you can measure**, read [`AMAP Conventions Reference`](build_and_simulate_3d_plants/reconstructing_an_mtg/amap_conventions_reference.md).
- If you want the first complete reconstruction workflow, go back to [`MTG Reconstruction Tutorial`](build_and_simulate_3d_plants/reconstructing_an_mtg/amap_quickstart.md).
