# AMAP Parity Matrix

!!! info "Page Info"
    - **Audience:** Advanced
    - **Prerequisites:** understanding of AMAP reconstruction terms
    - **Time:** 5 minutes
    - **Output:** Implementation parity status overview

This matrix summarizes current PlantGeom parity for AMAPStudio core reconstruction semantics.

## Implemented in This Release

| AMAP semantic area | Status | Notes |
| --- | --- | --- |
| AMAP profile as default behavior | Implemented | Applied by default in attribute-based reconstruction APIs. |
| Azimuth/Elevation orientation stage | Implemented | World-space override stage (`RotZ(azimuth)` then `RotY(-elevation)`). |
| Orthotropy / StiffnessAngle stage | Implemented | `StiffnessAngle` precedence, world-space bending axis from current main direction. |
| DeviationAngle stage | Implemented | World-space pre-rotation around global `+Z`. |
| Projection stage | Implemented | `NormalUp` and `Plagiotropy` with deterministic order (`NormalUp` first) and robust degenerate-frame handling. |
| Geometrical constraints (`GeometricalConstraint`) | Implemented | Cone/cylinder/plane families, including elliptic and cone-cylinder variants, with AMAP-style shared constraint initialization when a constraint object is reused. |
| Explicit-coordinate handling variants (AMAP coordinate delegates) | Implemented | `:explicit_start_end_required` (strict start/end coordinates) and `:explicit_rewire_previous` (previous-segment reorientation from explicit node positions) via `AmapReconstructionOptions(explicit_coordinate_mode=...)` (`coordinate_delegate_mode` alias supported). |
| Allometry delegate core semantics | Implemented | Width/height interpolation, component propagation (split-vs-copy), predecessor top smoothing, and complex accumulation from terminal components. |
| Stiffness propagation (`Stifness`, `StifnessTapering`) | Implemented | AMAP-style propagation writes `StiffnessAngle` to `/`-linked component children (toggle with `StiffnessApply`). |
| Stiffness straightening | Implemented | `StiffnessStraightening` dampens propagated bending after a configurable relative position (`0..1` or `0..100`). |
| Broken segment handling | Implemented | `Broken` forces downstream component `StiffnessAngle=-180` (AMAP `StiffnessBrokenDelegate` behavior). |
| Orientation reset aliases | Implemented | `OrientationReset` / `Global` reset local basis before insertion/euler stages. |
| Insertion alias compatibility | Implemented | `Insertion` accepted in insertion mode alias set. |
| Branching-order auto-compute | Implemented | `branching_order!` run once when needed and enabled. |
| Order-based insertion/phyllotaxy overrides | Implemented | `insertion_y_by_order` and `phyllotaxy_by_order` with `:override` / `:missing_only`. |
| Existing API surface | Implemented | Existing reconstruction calls are kept, with AMAP stages now active by default. |
| MeshBuilder-style extrusion profiles | Implemented | `extrude_profile_mesh` / `extrude_profile_refmesh` / `extrude_tube_mesh` plus helpers `circle_section_profile` and `leaflet_midrib_profile`. |
| Mesh path helpers (`makePath`, `makeSpline`, `makeInterpolation`, `makeCurve`) | Implemented | Available as `extrusion_make_path`, `extrusion_make_spline`, `extrusion_make_interpolation`, `extrusion_make_curve`. |
| Lathe helpers (`lathe`, `latheGen`) | Implemented | Available as `lathe_mesh` / `lathe_refmesh` and `lathe_gen_mesh` / `lathe_gen_refmesh`, with AMAP-like `method=:curve` profile interpolation. |
| Procedural refmesh caching | Implemented | `cache=...` in `*_refmesh` constructors preserves the "instantiate once, transform many" pattern for generated meshes. |

## Not Implemented Yet (Deferred)

| AMAP delegate / feature | Status | Workaround in PlantGeom |
| --- | --- | --- |
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
