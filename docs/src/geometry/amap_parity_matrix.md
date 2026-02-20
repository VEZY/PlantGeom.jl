# AMAP Parity Matrix

This matrix summarizes current PlantGeom parity for AMAPStudio core reconstruction semantics.

## Implemented in This Release

| AMAP semantic area | Status | Notes |
| --- | --- | --- |
| AMAP profile as default behavior | Implemented | Applied by default in attribute-based reconstruction APIs. |
| Azimuth/Elevation orientation stage | Implemented | World-space override stage (`RotZ(azimuth)` then `RotY(-elevation)`). |
| Orthotropy / StiffnessAngle stage | Implemented | `StiffnessAngle` precedence, world-space bending axis from current main direction. |
| DeviationAngle stage | Implemented | World-space pre-rotation around global `+Z`. |
| Projection stage | Implemented | `NormalUp` and `Plagiotropy` with deterministic order (`NormalUp` first) and robust degenerate-frame handling. |
| Stiffness propagation (`Stifness`, `StifnessTapering`) | Implemented | AMAP-style propagation writes `StiffnessAngle` to `/`-linked component children (toggle with `StiffnessApply`). |
| Orientation reset aliases | Implemented | `OrientationReset` / `Global` reset local basis before insertion/euler stages. |
| Insertion alias compatibility | Implemented | `Insertion` accepted in insertion mode alias set. |
| Branching-order auto-compute | Implemented | `branching_order!` run once when needed and enabled. |
| Order-based insertion/phyllotaxy overrides | Implemented | `insertion_y_by_order` and `phyllotaxy_by_order` with `:override` / `:missing_only`. |
| Existing API surface | Implemented | Existing reconstruction calls are kept, with AMAP stages now active by default. |

## Not Implemented Yet (Deferred)

| AMAP delegate / feature | Status | Workaround in PlantGeom |
| --- | --- | --- |
| Full `AllometryDelegate` parity | Deferred | Set per-node geometry attributes directly before reconstruction. |
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
