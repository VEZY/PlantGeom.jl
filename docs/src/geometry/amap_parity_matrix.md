# AMAP Parity Matrix

This matrix summarizes current PlantGeom parity for AMAPStudio core reconstruction semantics.

## Implemented in This Release

| AMAP semantic area | Status | Notes |
| --- | --- | --- |
| AMAP profile as default behavior | Implemented | Applied by default in attribute-based reconstruction APIs. |
| Azimuth/Elevation orientation stage | Implemented | World-space override stage (`RotZ(azimuth)` then `RotY(-elevation)`). |
| Orthotropy / StiffnessAngle stage | Implemented | `StiffnessAngle` precedence, world-space bending axis from current main direction. |
| DeviationAngle stage | Implemented | World-space pre-rotation around global `+Z`. |
| Projection stage | Implemented | `NormalUp` and `Plagiotropy` with deterministic order (`NormalUp` first). |
| Orientation reset aliases | Implemented | `OrientationReset` / `Global` reset local basis before insertion/euler stages. |
| Insertion alias compatibility | Implemented | `Insertion` accepted in insertion mode alias set. |
| Branching-order auto-compute | Implemented | `branching_order!` run once when needed and enabled. |
| Order-based insertion/phyllotaxy overrides | Implemented | `insertion_y_by_order` and `phyllotaxy_by_order` with `:override` / `:missing_only`. |
| Existing API surface | Implemented | Existing reconstruction calls are kept, with AMAP stages now active by default. |

## Partially Implemented / Simplified vs AMAPStudio

| AMAP area | Status | Current PlantGeom behavior |
| --- | --- | --- |
| Orthotropy/stiffness propagation details | Partial | Core local-node semantics implemented, full delegate propagation rules not yet replicated. |
| Projection heuristics edge cases | Partial | Deterministic projection and frame rebuild implemented, but not every AMAPStudio corner-case branch. |

## Not Implemented Yet (Deferred)

| AMAP delegate / feature | Status | Workaround in PlantGeom |
| --- | --- | --- |
| Full `AllometryDelegate` parity | Deferred | Set per-node geometry attributes directly before reconstruction. |
| Full `StiffnessDelegate` child propagation (`Stifness`, `StiffnessTapering`) | Deferred | Explicitly set `StiffnessAngle` on nodes that require bending. |
| Geometrical constraints (`GeometricalConstraint` cones/cylinders/planes) | Deferred | Apply custom post-transforms or custom filtering externally. |
| Coordinate delegate variants using absolute endpoints (`EndX/EndY/EndZ`) | Deferred | Use explicit `XX/YY/ZZ` or topology placement. |
| Topology editor specific behaviors | Deferred | Use explicit conventions and `conventions=Dict(...)` overrides. |

## Recommendation

For AMAP-like reconstruction from MTG attributes, start with:

```julia
set_geometry_from_attributes!(
    mtg,
    ref_meshes;
    convention=default_amap_geometry_convention(),
)
```

Then specialize with:

- custom `GeometryConvention` per organ via `conventions=Dict(...)`
- custom `AmapReconstructionOptions(...)` order maps and aliases
