# AMAP Conventions Reference

This page documents the AMAP core profile used by default:

```julia
set_geometry_from_attributes!(
    mtg,
    ref_meshes;
    convention=default_amap_geometry_convention(),
)
```

If you are new to AMAP-style reconstruction, read this page in this order:

1. Alias tables (what attribute names are accepted).
2. Practical parameter guide (what each parameter changes in geometry).
3. Option impact plots (what the changes look like in 3D).

The same MTG can be reconstructed very differently depending on orientation and insertion options. Most differences come from a small set of parameters (`InsertionMode`, insertion/euler angles, order overrides, and verticil handling), so those are explained with short examples below.

## 1. Naming Conventions (Column Aliases)

### 1.1 Geometry Convention (`default_amap_geometry_convention()`)

#### Scale columns

| Semantic meaning | Alias lookup order | Default |
| --- | --- | --- |
| Length | `Length`, `length`, `L`, `l` | `1.0` |
| Width | `Width`, `width`, `W`, `w` | `1.0` |
| Thickness | `Thickness`, `thickness`, `Depth`, `depth` | Width value |

#### Angle columns

| Semantic meaning | Alias lookup order | Frame | Unit default | Default |
| --- | --- | --- | --- | --- |
| X insertion | `XInsertionAngle`, `x_insertion_angle`, `xinsertionangle` | Local | deg | `0` |
| Y insertion | `YInsertionAngle`, `y_insertion_angle`, `yinsertionangle` | Local | deg | `0` |
| Z insertion | `ZInsertionAngle`, `z_insertion_angle`, `zinsertionangle` | Local | deg | `0` |
| X Euler | `XEuler`, `x_euler`, `xeuler` | Local | deg | `0` |
| Y Euler | `YEuler`, `y_euler`, `yeuler` | Local | deg | `0` |
| Z Euler | `ZEuler`, `z_euler`, `zeuler` | Local | deg | `0` |

#### Translation columns

| Semantic meaning | Alias lookup order | Default |
| --- | --- | --- |
| X translation | `XX`, `xx` | `0.0` |
| Y translation | `YY`, `yy` | `0.0` |
| Z translation | `ZZ`, `zz` | `0.0` |

### 1.2 AMAP Options (`default_amap_reconstruction_options()`)

| Option semantic | Default aliases / values |
| --- | --- |
| Insertion mode aliases | `InsertionMode`, `insertion_mode`, `Insertion`, `insertion` |
| Phyllotaxy aliases | `Phyllotaxy`, `phyllotaxy`, `PHYLLOTAXY` |
| Verticil mode | `:rotation360` |
| Azimuth aliases | `Azimuth`, `azimuth` |
| Elevation aliases | `Elevation`, `elevation` |
| Deviation aliases | `DeviationAngle`, `deviation_angle` |
| Orthotropy aliases | `Orthotropy`, `orthotropy` |
| Stiffness angle aliases | `StiffnessAngle`, `stiffness_angle` |
| Stiffness source aliases | `Stifness`, `stifness`, `Stiffness`, `stiffness` |
| Stiffness tapering aliases | `StifnessTapering`, `stifness_tapering`, `StiffnessTapering`, `stiffness_tapering` |
| Stiffness apply aliases | `StiffnessApply`, `stiffness_apply` |
| Stiffness straightening aliases | `StiffnessStraightening`, `stiffness_straightening` |
| Broken-segment aliases | `Broken`, `broken` |
| Plagiotropy aliases | `Plagiotropy`, `plagiotropy` |
| NormalUp aliases | `NormalUp`, `normal_up` |
| Orientation reset aliases | `OrientationReset`, `orientation_reset`, `Global`, `global` |
| Endpoint X aliases | `EndX`, `end_x`, `endx` |
| Endpoint Y aliases | `EndY`, `end_y`, `endy` |
| Endpoint Z aliases | `EndZ`, `end_z`, `endz` |
| Order attribute | `:branching_order` |
| Auto order compute | `true` |
| Order override mode | `:override` |
| Insertion-by-order map | empty `Dict{Int,Float64}` |
| Phyllotaxy-by-order map | empty `Dict{Int,Float64}` |

### 1.3 Topology columns (used when `XX/YY/ZZ` are missing)

| Column | Aliases | Meaning | Default |
| --- | --- | --- | --- |
| Offset | `Offset`, `offset` | Position along bearer where `+` organ starts | Bearer `Length` |
| Border insertion offset | `BorderInsertionOffset`, `border_insertion_offset`, `BorderOffset`, `border_offset` | Lateral shift for insertion mode | Depends on mode |
| Insertion mode | `InsertionMode`, `insertion_mode`, `Insertion`, `insertion` | `CENTER`, `BORDER` (`SURFACE` alias), `WIDTH`, `HEIGHT` | `BORDER` |
| Phyllotaxy | `Phyllotaxy`, `phyllotaxy`, `PHYLLOTAXY` | Fallback insertion azimuth when `XInsertionAngle` is missing | `0` |

First matching alias wins.

## 2. Parameter Guide for First-Time Users

### 2.1 Size and scale parameters

`Length`, `Width`, and `Thickness` scale the reference mesh in local coordinates (`+X` is organ length in AMAP). If `Thickness` is absent, width is reused, which can make flat organs look unnaturally thick.

Example: changing a leaf from `Length=0.20` to `Length=0.32` stretches only the local `+X` axis and increases overlap with neighbors without changing insertion position.

When to use what:

- Use measured organ dimensions when available.
- Keep `Thickness` explicit for leaves if your reference mesh is not already very thin.
- Use a single fallback width/thickness policy only for synthetic plants or quick debugging.

### 2.2 Insertion angles and Euler angles

Insertion angles define attachment orientation relative to the bearer; Euler angles are post-attachment local refinements.

Example: increasing `YInsertionAngle` from `35` to `65` lifts a leaf away from the stem axis. Adding `ZEuler=20` then twists that leaf around its own axis without changing its insertion anchor.

When to use what:

- Use insertion angles for phyllotaxy/branch architecture.
- Use Euler angles for mesh-pose corrections (twist/roll) after topology is correct.
- Avoid compensating missing insertion data with large Euler rotations, because that breaks architectural meaning.

### 2.3 Explicit translation vs topology placement

When `XX/YY/ZZ` are present, placement is explicit. When missing, PlantGeom reconstructs position from topology (`Offset`, insertion mode, bearer frame).

With endpoint columns (`EndX`/`EndY`/`EndZ`), PlantGeom uses:

- start = explicit translation if present, else topology-derived base
- end = provided endpoint coordinates
- orientation and effective `Length` = inferred from `(start -> end)`

Example: setting `XX/YY/ZZ` for one leaf detaches it from topology and can produce a correct but non-botanical placement if coordinates are inconsistent with bearer geometry.

When to use what:

- Use topology-based placement for botanical reconstructions.
- Use explicit `XX/YY/ZZ` when ingesting already solved 3D coordinates from another pipeline.
- Use `EndX`/`EndY`/`EndZ` when start-end coordinates are known and must dominate angle-derived orientation.

### 2.6 Endpoint coordinates (`EndX`/`EndY`/`EndZ`)

`EndX`/`EndY`/`EndZ` activate endpoint-driven reconstruction for that node.

Practical precedence:

1. Base position is resolved first (explicit `XX/YY/ZZ` if present, otherwise topology).
2. If `EndX`/`EndY`/`EndZ` are all numeric, orientation and length are computed from base-to-end.
3. Angle stages (`Insertion`, azimuth/elevation, orthotropy/stiffness angle, deviation, Euler, projection) are skipped for that node.
4. Width/thickness scaling still uses `Width`/`Thickness`.

Notes:

- If only some endpoint columns are present, endpoint override is ignored (lenient fallback).
- If endpoint equals base (zero-length vector), endpoint override is ignored.
- Successor `"<"` nodes continue from this computed endpoint through normal topology rules.

### 2.4 AMAP option parameters (practical decisions)

`InsertionMode`: controls lateral insertion offset on the bearer cross-section.

- `CENTER`: attach at section center.
- `BORDER` / `SURFACE`: project insertion direction to the bearer cross-section and stick to the section border.
- `WIDTH`: shift along width axis.
- `HEIGHT`: shift along height axis.

Important: these axes are in the **bearer local frame** (the bearer reference mesh axes), not in global/world axes.

For `default_amap_geometry_convention()` (length axis = local `+X`):

- width axis is local `+Y`
- height axis is local `+Z` (same direction as thickness/top-height semantics)

So `WIDTH` means a lateral shift in local `Y`, and `HEIGHT` means a lateral shift in local `Z`.

Use `BORDER`/`SURFACE` for "stick to bearer surface" behavior; use `CENTER` for neutral attachment; use `WIDTH`/`HEIGHT` when organs are known to emerge preferentially on one side of the local cross-section.

`verticil_mode`: controls sibling spread when `XInsertionAngle` is missing.

- `:rotation360`: siblings are distributed around 360 degrees.
- `:none`: no additional spread term.

Use `:rotation360` for whorled/regular sibling insertion with missing azimuth data; use `:none` if azimuth is already fully defined elsewhere.

`order_override_mode` with order maps (`insertion_y_by_order`, `phyllotaxy_by_order`):

- `:override`: map values replace present attributes.
- `:missing_only`: map values fill only missing attributes.

Use `:override` for strict calibration by branch order. Use `:missing_only` when measured node-level values must stay authoritative.

`StiffnessAngle` vs `Orthotropy`: both bend orientation, but `StiffnessAngle` takes precedence if both are present.

Use `StiffnessAngle` when a mechanical bending angle is available; keep `Orthotropy` as a fallback heuristic.

`OrientationReset` (`Global`): resets the orientation basis before insertion/euler stages.

Use it when switching from inherited frame behavior to absolute local interpretation at selected nodes.

`NormalUp` and `Plagiotropy`: projection stages applied in this order.

`NormalUp` is mainly a robustness option for dorsiventral organs (typical leaves): it keeps the organ normal oriented toward world `+Z` after insertion/euler/bending stages, so leaves are less likely to end up upside-down due to noisy angles.

Practical effect:

- It does not move the insertion point.
- It does not redefine topology.
- It adjusts orientation to keep the organ "up-facing" in world space.

Use `NormalUp=true` for leaf datasets where adaxial/abaxial flips appear. Add `Plagiotropy` only if you also need directional projection control in the insertion plane.

### 2.5 Why `node_convention.length_axis` is critical

`node_convention.length_axis` defines which local reference-mesh axis is considered the organ main axis.

This affects multiple stages, not just scaling:

- allometry: which axis receives `Length`
- insertion frame: which direction is considered the organ direction
- bending (`Orthotropy`/`StiffnessAngle`): bending axis is derived from this main direction
- projection (`NormalUp`/`Plagiotropy`): which columns are treated as direction/secondary/normal
- topology placement defaults: how "along the bearer axis" is interpreted

So if the reference mesh was authored with length on local `+Z` but the convention says `length_axis=:x`, orientation and projection can look "wrong" even with correct angle values.

Rule of thumb:

- Use `default_amap_geometry_convention()` (`length_axis=:x`) for AMAP-style meshes.
- Use a custom `GeometryConvention(..., length_axis=:z)` when meshes are authored with length on local `+Z`.

`Stifness` / `StifnessTapering` propagation:

- If a node has a stiffness value and `/`-linked component children, PlantGeom propagates computed `StiffnessAngle` values to those components.
- `StiffnessApply=false` disables this propagation for that node.
- Positive `Stifness` propagates downward-sign bending angles; negative values propagate upward-sign bending angles.
- `StifnessTapering` controls the curvature profile (`0.5` default when missing).
- `StiffnessStraightening` (0..1 or 0..100) progressively damps propagated bending after that relative position.
- `Broken` (0..100) forces downstream component angles to `-180` after the break threshold.

## 3. Stage Order and Semantics

Reconstruction applies stages in this order:

1. Translation / topology base frame.
2. Endpoint override check (`EndX`/`EndY`/`EndZ`).
3. Insertion angles + insertion mode offset.
4. Azimuth/Elevation world orientation override.
5. Orthotropy/StiffnessAngle bending.
6. DeviationAngle world rotation.
7. Euler stage.
8. Projection stage (`NormalUp`, then `Plagiotropy`).
9. Stiffness propagation stage (`Stifness` / `StifnessTapering`) writing `StiffnessAngle` on `/` components.

Key rules:

- `StiffnessAngle` takes precedence over `Orthotropy`.
- `OrientationReset=true` resets orientation basis to the AMAP base orientation for that node before insertion/euler stages.
- If both projection flags are enabled, `NormalUp` is applied before `Plagiotropy`.
- Propagated stiffness angles are written to component children before those children are reconstructed.
- Explicit translation attributes keep the node position explicit; topology-based placement is used only when `XX/YY/ZZ` are absent.
- When endpoint override is active, angle stages are skipped and node `Length` is inferred from endpoint distance.

## 4. Local vs Global Angles in `GeometryConvention`

Angle scope is controlled per entry in `GeometryConvention.angle_map`:

- Local angle (`frame=:local`): composed as `T = T ∘ R`.
- Global angle (`frame=:global`): composed as `T = recenter(R, pivot) ∘ T`.

Global pivots:

- `:origin`
- Attribute tuple, e.g. `(:pivot_x, :pivot_y, :pivot_z)`
- Numeric tuple, e.g. `(0.0, 0.0, 0.0)`

Minimal example:

```julia
base = default_amap_geometry_convention()
leaf_conv = GeometryConvention(
    scale_map=base.scale_map,
    angle_map=[
        (names=[:XInsertionAngle], axis=:x, frame=:local, unit=:deg, pivot=:origin),
        (names=[:YInsertionAngle], axis=:y, frame=:local, unit=:deg, pivot=:origin),
        (names=[:Heading], axis=:z, frame=:global, unit=:deg, pivot=(:pivot_x, :pivot_y, :pivot_z)),
        (names=[:XEuler], axis=:x, frame=:local, unit=:deg, pivot=:origin),
    ],
    translation_map=base.translation_map,
    length_axis=:x,
)
```

## 5. Order-Based Defaults and Overrides

When `auto_compute_branching_order=true` and no numeric order exists in `order_attribute`, PlantGeom computes `branching_order!` automatically.

Then for each node:

- `insertion_y_by_order[order]` can override `YInsertionAngle`.
- `phyllotaxy_by_order[order]` can override the phyllotaxy fallback used when `XInsertionAngle` is missing.

Override modes:

- `:override`: map values replace attributes when available.
- `:missing_only`: map values apply only if the attribute is missing.

Effective fallback for missing `XInsertionAngle`:

`effective_x_insertion = phyllotaxy_effective + verticil_term`

- `verticil_mode=:rotation360` (default): `verticil_term = 360 * rank / total`
- `verticil_mode=:none`: `verticil_term = 0`

## 6. Option Impact Examples

```@setup amapref
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics
using CairoMakie
using Colors

CairoMakie.activate!()

const Tri = GeometryBasics.TriangleFace{Int}

function _example_ref_meshes()
    stem_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), 0.5),
    )
    leaf_mesh = GeometryBasics.Mesh(
        [
            Point(0.0, -0.06, -0.015),
            Point(0.0, 0.06, 0.025),
            Point(0.25, 0.0, 0.035),
            Point(1.0, 0.0, 0.0),
            Point(0.6, -0.2, -0.04),
            Point(0.6, 0.2, 0.08),
        ],
        Tri[
            Tri(1, 2, 3),
            Tri(3, 5, 4),
            Tri(3, 6, 4),
        ],
    )

    Dict(
        "Internode" => RefMesh("Stem", stem_mesh, RGB(0.58, 0.44, 0.30)),
        "Leaf" => RefMesh("Leaf", leaf_mesh, RGB(0.16, 0.55, 0.22)),
    )
end

function _example_ref_meshes_verticil()
    stem_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), 0.5),
    )

    # Deliberately eccentric leaf mesh (not centered on local +X axis) so
    # rotation around +X is visually obvious in the plot.
    leaf_mesh = GeometryBasics.Mesh(
        [
            Point(0.0, 0.12, 0.00),
            Point(0.0, 0.22, 0.05),
            Point(0.30, 0.18, 0.03),
            Point(1.00, 0.24, 0.02),
            Point(0.62, 0.32, 0.09),
            Point(0.55, 0.08, -0.05),
        ],
        Tri[
            Tri(1, 2, 3),
            Tri(3, 5, 4),
            Tri(3, 4, 6),
        ],
    )

    Dict(
        "Internode" => RefMesh("Stem", stem_mesh, RGB(0.58, 0.44, 0.30)),
        "Leaf" => RefMesh("Leaf", leaf_mesh, RGB(0.16, 0.55, 0.22)),
    )
end

const REF_MESHES = _example_ref_meshes()
const REF_MESHES_VERTICIL = _example_ref_meshes_verticil()
const CONV = default_amap_geometry_convention()
const COLOR_MAP = Dict("Stem" => RGB(0.58, 0.44, 0.30), "Leaf" => RGB(0.14, 0.52, 0.22))

function _base_bearer!(node)
    node[:Length] = 0.22
    node[:Width] = 0.08
    node[:Thickness] = 0.045
    node[:TopWidth] = 0.10
    node[:TopHeight] = 0.045
    node
end

function _new_leaf(parent, idx)
    leaf = Node(parent, NodeMTG("+", "Leaf", idx, 2))
    leaf[:Length] = 0.24
    leaf[:Width] = 0.12
    leaf[:Thickness] = 0.002
    leaf[:Offset] = 0.18
    leaf[:BorderInsertionOffset] = 0.02
    leaf
end

function insertion_mode_example(mode::String)
    mtg = Node(NodeMTG("/", "Plant", 1, 1))
    bearer = Node(mtg, NodeMTG("/", "Internode", 1, 2))
    _base_bearer!(bearer)
    # Exaggerated proportions for documentation visibility.
    bearer[:Length] = 0.10
    bearer[:Width] = 0.16
    bearer[:Thickness] = 0.14
    bearer[:TopWidth] = 0.18
    bearer[:TopHeight] = 0.16

    leaf = _new_leaf(bearer, 1)
    leaf[:Length] = 0.18
    leaf[:Offset] = 0.08
    leaf[:BorderInsertionOffset] = missing
    leaf[:InsertionMode] = mode
    leaf[:XInsertionAngle] = 35.0
    leaf[:YInsertionAngle] = 42.0

    set_geometry_from_attributes!(mtg, REF_MESHES; convention=CONV)
    mtg
end

function verticil_mode_example(mode::Symbol)
    mtg = Node(NodeMTG("/", "Plant", 1, 1))
    bearer = Node(mtg, NodeMTG("/", "Internode", 1, 2))
    _base_bearer!(bearer)
    bearer[:Length] = 0.14
    bearer[:Width] = 0.06
    bearer[:Thickness] = 0.04
    bearer[:TopWidth] = 0.08
    bearer[:TopHeight] = 0.04

    for leaf_idx in 1:6
        leaf = _new_leaf(bearer, leaf_idx)
        leaf[:Length] = 0.15
        leaf[:Width] = 0.085
        leaf[:Offset] = 0.85 * bearer[:Length]
        leaf[:InsertionMode] = "CENTER"
        leaf[:YInsertionAngle] = 42.0
        leaf[:Phyllotaxy] = 0.0
        # no XInsertionAngle on purpose
    end

    reconstruct_geometry_from_attributes!(mtg, REF_MESHES_VERTICIL; convention=CONV, verticil_mode=mode)
    mtg
end

function order_override_example(mode::Symbol)
    mtg = Node(NodeMTG("/", "Plant", 1, 1))
    bearer = Node(mtg, NodeMTG("/", "Internode", 1, 2))
    _base_bearer!(bearer)

    leaf_a = _new_leaf(bearer, 1)
    leaf_a[:InsertionMode] = "CENTER"
    leaf_a[:XInsertionAngle] = 25.0
    leaf_a[:branching_order] = 2

    leaf_b = _new_leaf(bearer, 2)
    leaf_b[:InsertionMode] = "CENTER"
    leaf_b[:XInsertionAngle] = 205.0
    leaf_b[:YInsertionAngle] = 15.0
    leaf_b[:branching_order] = 2

    opts = AmapReconstructionOptions(
        insertion_y_by_order=Dict(2 => 60.0),
        order_override_mode=mode,
    )

    reconstruct_geometry_from_attributes!(mtg, REF_MESHES; convention=CONV, amap_options=opts)
    mtg
end

function stiffness_propagation_example(mode::Symbol)
    mtg = Node(NodeMTG("/", "Plant", 1, 1))
    axis = Node(mtg, NodeMTG("/", "AxisNode", 1, 2))

    # AMAP-style setup:
    # each controller node carries stiffness and writes StiffnessAngle to
    # its linked components; successor "<" nodes then continue from the last
    # component top.
    n_segments = 4
    for i in 1:n_segments
        axis[:Length] = 20.0
        axis[:Width] = 0.1
        axis[:Thickness] = 0.1
        axis[:Stifness] = 800.0
        axis[:StifnessTapering] = 0.5
        axis[:StiffnessApply] = mode == :propagate

        # Two components are used so propagated angle is non-zero on the
        # second (visible) segment.
        anchor = Node(axis, NodeMTG("/", "AxisDummy", 2 * i - 1, 3))
        anchor[:Length] = 1.0
        anchor[:Width] = 0.05
        anchor[:Thickness] = 0.05

        seg = Node(axis, NodeMTG("/", "AxisSegment", 2 * i, 3))
        seg[:Length] = 1.0
        seg[:Width] = max(0.35 - 0.03 * (i - 1), 0.12)
        seg[:Thickness] = seg[:Width]

        if i < n_segments
            nxt = Node(axis, NodeMTG("<", "AxisNode", i + 1, 2))
            nxt[:Length] = 20.0
            nxt[:Width] = 0.1
            nxt[:Thickness] = 0.1
            axis = nxt
        end
    end

    local_ref_meshes = Dict(
        "AxisSegment" => RefMesh(
            "Stem",
            GeometryBasics.mesh(
                GeometryBasics.Cylinder(Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), 0.5),
            ),
            RGB(0.58, 0.44, 0.30),
        ),
    )

    reconstruct_geometry_from_attributes!(mtg, local_ref_meshes; convention=CONV, root_align=false)
    mtg
end

function _scene_bounds(scene)
    xmin_all = Inf
    xmax_all = -Inf
    ymin_all = Inf
    ymax_all = -Inf
    zmin_all = Inf
    zmax_all = -Inf

    traverse!(scene) do node
        haskey(node, :geometry) || return
        mesh = refmesh_to_mesh(node)
        for p in GeometryBasics.coordinates(mesh)
            x = Float64(p[1])
            y = Float64(p[2])
            z = Float64(p[3])
            xmin_all = min(xmin_all, x)
            xmax_all = max(xmax_all, x)
            ymin_all = min(ymin_all, y)
            ymax_all = max(ymax_all, y)
            zmin_all = min(zmin_all, z)
            zmax_all = max(zmax_all, z)
        end
    end

    if !isfinite(xmin_all)
        return (-1.0, 1.0, -1.0, 1.0, -1.0, 1.0)
    end

    return (xmin_all, xmax_all, ymin_all, ymax_all, zmin_all, zmax_all)
end

function _plot_modes(
    modes,
    builder;
    titles=string.(modes),
    size=(1200, 360),
    ncols=length(modes),
    azimuth=1.05pi,
    elevation=0.42,
    zoom_padding=0.06,
)
    scenes = [builder(mode) for mode in modes]
    bounds = _scene_bounds.(scenes)

    xmin_all = minimum(first.(bounds))
    xmax_all = maximum(getindex.(bounds, 2))
    ymin_all = minimum(getindex.(bounds, 3))
    ymax_all = maximum(getindex.(bounds, 4))
    zmin_all = minimum(getindex.(bounds, 5))
    zmax_all = maximum(last.(bounds))

    xpad = max((xmax_all - xmin_all) * zoom_padding, 1e-3)
    ypad = max((ymax_all - ymin_all) * zoom_padding, 1e-3)
    zpad = max((zmax_all - zmin_all) * zoom_padding, 1e-3)

    fig = Figure(size=size)
    ncols_use = max(1, Int(ncols))
    for (i, scene) in enumerate(scenes)
        row = cld(i, ncols_use)
        col = mod1(i, ncols_use)
        ax = Axis3(
            fig[row, col],
            aspect=:data,
            title=titles[i],
            azimuth=azimuth,
            elevation=elevation,
        )
        plantviz!(ax, scene, color=COLOR_MAP)
        limits!(
            ax,
            xmin_all - xpad,
            xmax_all + xpad,
            ymin_all - ypad,
            ymax_all + ypad,
            zmin_all - zpad,
            zmax_all + zpad,
        )
        hidedecorations!(ax)
    end
    fig
end
```

### 6.1 `InsertionMode`: `BORDER` (default) vs `CENTER` vs `WIDTH` vs `HEIGHT`

`InsertionMode` mainly changes where the organ base sits on the bearer cross-section. In practice, this changes self-shading and apparent clumping even if all angles stay identical.

In this example, with AMAP defaults (`length=+X`) and local frame = reference mesh axes, the distinction is:

- `BORDER`: offset along the projected insertion direction, to place the organ on bearer surface
- `WIDTH`: offset along local `Y`
- `HEIGHT`: offset along local `Z`

Use `CENTER` for symmetric prototypes, `WIDTH` when organs are known to emerge on lateral flanks, and `HEIGHT` when emergence is biased toward upper/lower surfaces.  
If you want "stick to bearer surface" behavior, use `InsertionMode="BORDER"` (or `InsertionMode="SURFACE"` alias): this follows insertion direction and projects to the bearer cross-section border.

Why the four panels differ:

- All four cases use the same insertion angles and `Offset` along the internode.
- Only the lateral insertion direction changes (`CENTER` = none, `BORDER` = projected insertion direction, `WIDTH` = local `Y`, `HEIGHT` = local `Z`).
- So the leaf keeps similar orientation, but its attachment point moves on different cross-section directions.
- In this demo, `BorderInsertionOffset` is intentionally left missing so defaults are mode-dependent:
  `BORDER -> TopWidth/2`, `WIDTH -> TopWidth/2`, `HEIGHT -> TopHeight/2`.
- The side can appear left or right depending on orientation because WIDTH/HEIGHT pick `+axis` or `-axis`
  based on alignment with the leaf insertion direction (it is not “always +Y” or “always +Z” in screen space).

Offset and insertion mode are independent:

- `Offset`: moves the attachment point **along the internode axis** (`+X` here).
- `BORDER`/`WIDTH`/`HEIGHT`: move the attachment point **across the internode cross-section**.

```@example amapref
_plot_modes(
    ("BORDER", "CENTER", "WIDTH", "HEIGHT"),
    insertion_mode_example;
    titles=("BORDER (default)", "CENTER", "WIDTH", "HEIGHT"),
    size=(960, 760),
    ncols=2,
    azimuth=1.22pi,
    elevation=0.30,
    zoom_padding=0.035,
)
```

### 6.2 `verticil_mode`: sibling spread when `XInsertionAngle` is missing

When insertion azimuth is missing, `verticil_mode` controls how sibling organs are separated. `:rotation360` reduces overlap by design; `:none` keeps siblings close to the same fallback azimuth.

Use `:rotation360` for regular whorls with incomplete azimuth measurements. Use `:none` if azimuth is already controlled by measured attributes or external rules.

What this figure is doing:

- One internode has 6 sibling leaves.
- Leaves intentionally have no `XInsertionAngle` (to trigger `verticil_mode` behavior).
- All siblings share the same `Phyllotaxy` and `YInsertionAngle`; only `verticil_mode` differs.

So the visible difference should be:

- `:none`: sibling leaves keep the same fallback azimuth and overlap.
- `:rotation360`: siblings receive an additional spread term (`0`, `60`, `120`, ... degrees here), so they form a whorl around the bearer.

To make this easier to see, the demo uses one short bearer with 6 sibling leaves, missing `XInsertionAngle`,
and an eccentric leaf mesh so azimuth spread is visually obvious.

```@example amapref
_plot_modes(
    (:none, :rotation360),
    verticil_mode_example;
    titles=("none: siblings overlap", "rotation360: siblings spread"),
    size=(860, 360),
    azimuth=1.18pi,
    elevation=0.38,
    zoom_padding=0.04,
)
```

### 6.3 Order-map overrides (`:override` vs `:missing_only`)

Order maps are useful for calibrated architecture classes. `:override` enforces class-level values everywhere; `:missing_only` preserves measured node attributes and only fills gaps.

Use `:override` for strict synthetic generators. Use `:missing_only` for mixed datasets where some organs are measured and others are inferred.

What this specific example does:

- Two leaves share `branching_order = 2`.
- The order map sets `insertion_y_by_order = Dict(2 => 60.0)`.
- Leaf A has no `YInsertionAngle` in attributes.
- Leaf B has a measured `YInsertionAngle = 15.0`.

So the visible difference is:

- `:override`: both leaves use `60.0`, giving a symmetric high insertion posture.
- `:missing_only`: Leaf A uses `60.0`, Leaf B keeps `15.0`, giving a clearly asymmetric pair.

```@example amapref
_plot_modes(
    (:override, :missing_only),
    order_override_example;
    size=(860, 360),
    azimuth=1.02pi,
    elevation=0.44,
    zoom_padding=0.045,
)
```

### 6.4 Stiffness propagation (`StiffnessApply=false` vs `true`)

This option controls whether node-level `Stifness`/`StifnessTapering` are converted into propagated `StiffnessAngle` values for `/`-linked component children.

Important: this is a **component-based bending** mechanism. A single undecomposed reference mesh will not be smoothly bent by this stage; you need a segmented organ representation (explicit per-segment nodes).

What this figure is doing:

- Each controller node has stiffness (`Stifness`, `StifnessTapering`) and two `/` components:
  an invisible anchor + a visible cylindrical segment.
- `StiffnessApply=true` propagates a non-zero `StiffnessAngle` to the visible component.
- Successor `"<"` nodes continue from the last component top (AMAPStudio-like behavior), so propagated component bending changes downstream position.
- Only `StiffnessApply` changes between panels.

Topology sketch:

```text
AxisNode(i)
├─ / AxisDummy   (anchor, hidden)
└─ / AxisSegment (visible)
< AxisNode(i+1) starts at top(AxisSegment)
```

So the visible difference should be:

- `StiffnessApply=false`: segments stay aligned.
- `StiffnessApply=true`: segments bend and the chain goes downward.

Important: like AMAPStudio, bending changes orientation, and topology controls where the next element starts.
If you set explicit `XX/YY/ZZ`, you override this topological positioning.

```@example amapref
_plot_modes(
    (:disabled, :propagate),
    stiffness_propagation_example;
    titles=("StiffnessApply=false", "StiffnessApply=true"),
    size=(980, 320),
    azimuth=1.5pi,
    elevation=0.20,
    zoom_padding=0.05,
)
```
