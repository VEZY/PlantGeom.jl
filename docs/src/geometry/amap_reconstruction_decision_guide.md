# AMAP Reconstruction Decision Guide

!!! info "Page Info"
    - **Audience:** Intermediate
    - **Prerequisites:** AMAP quickstart familiarity
    - **Time:** 8 minutes
    - **Output:** Selection of explicit-coordinate handling mode

Use this page when you know what coordinates you have, but you are unsure which reconstruction option to pick.

Technical API name:
- `AmapReconstructionOptions(explicit_coordinate_mode=...)`
- `coordinate_delegate_mode` remains supported as an alias.

User-facing meaning:
- this option is the **explicit-coordinate handling mode**.

## 1. Quick Chooser

| If your data has... | And you want... | Use | Why |
| --- | --- | --- | --- |
| No `XX/YY/ZZ` | Standard MTG topology reconstruction | `:topology_default` | Uses topology + insertion/euler pipeline only. |
| `XX/YY/ZZ` on some nodes, no `EndX/EndY/EndZ` | Keep visible geometry on explicit nodes | `:topology_default` | Explicit start sets base; node still creates a segment. |
| `XX/YY/ZZ` on some nodes, no `EndX/EndY/EndZ` | Mimic AMAP topology-editor rewiring | `:explicit_rewire_previous` | Explicit point rewires previous segment; explicit node becomes a point-anchor. |
| `XX/YY/ZZ` and complete `EndX/EndY/EndZ` | Strict start/end interpretation | `:explicit_start_end_required` | Segment is built only from start/end data. |
| `XX/YY/ZZ` but missing some endpoint values | Strict behavior (reject incomplete endpoints) | `:explicit_start_end_required` | Nodes with missing end coordinates are omitted by design. |

## 2. Most Common Confusion

### "I have start coordinates but not end coordinates. What are my options?"

You have three valid strategies:

1. `:topology_default`
   Keep all visible segments. Explicit start coordinates place node bases, and segment direction/length are still resolved by the regular reconstruction stages.
2. `:explicit_rewire_previous`
   Treat explicit coordinates as control points that reorient the previous segment. The explicit node itself is a point-anchor (zero-length geometry).
3. `:explicit_start_end_required`
   Enforce strict start/end semantics. If `EndX/EndY/EndZ` is missing, the node geometry is omitted.

Definition: point-anchor = node kept in topology, but represented as a point (zero-length geometry, no cylinder).

Important clarification for `:explicit_rewire_previous`:
- It does not mean "draw cylinders only between explicit nodes".
- It means explicit nodes act as control points:
  - previous segment is rewired to the explicit coordinate;
  - explicit node becomes a point-anchor;
  - following non-explicit nodes are still regular visible segments.

So if you provide explicit coordinates every 10 nodes, you usually get one point-anchor every 10 nodes, with regular cylinders between those control points.

Note on the resulting geometry:
- Fewer cylinders does **not** necessarily mean data loss.
- It can mean a node is intentionally represented as a point-anchor (`:explicit_rewire_previous`) or intentionally omitted (`:explicit_start_end_required` with missing end).

## 3. Minimal Code Patterns

```julia
# A) Keep explicit-start nodes as visible segments
opts = AmapReconstructionOptions(explicit_coordinate_mode=:topology_default)

# B) Rewire previous segment from explicit node position
opts = AmapReconstructionOptions(explicit_coordinate_mode=:explicit_rewire_previous)

# C) Strict start/end mode (incomplete endpoints are omitted)
opts = AmapReconstructionOptions(explicit_coordinate_mode=:explicit_start_end_required)

set_geometry_from_attributes!(
    mtg,
    ref_meshes;
    convention=default_amap_geometry_convention(),
    amap_options=opts,
)
```

## 4. Practical Recommendation

Start with `:topology_default`.  
Switch to `:explicit_rewire_previous` only when importing topology-editor style coordinates.  
Use `:explicit_start_end_required` only when your endpoint columns are complete and trusted.

Practical tip for nice reconstructions with `:explicit_rewire_previous`:
- Do not put explicit coordinates on every node.
- Use sparse control points (for example every 2nd or 3rd internode), so anchor nodes remain rare and most organs stay visible as segments.
