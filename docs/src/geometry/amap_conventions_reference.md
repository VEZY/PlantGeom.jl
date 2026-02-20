# AMAP Conventions Reference

This page documents the AMAP core profile used by default:

```julia
set_geometry_from_attributes!(
    mtg,
    ref_meshes;
    convention=default_amap_geometry_convention(),
)
```

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
| Plagiotropy aliases | `Plagiotropy`, `plagiotropy` |
| NormalUp aliases | `NormalUp`, `normal_up` |
| Orientation reset aliases | `OrientationReset`, `orientation_reset`, `Global`, `global` |
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
| Insertion mode | `InsertionMode`, `insertion_mode`, `Insertion`, `insertion` | `CENTER`, `BORDER`, `WIDTH`, `HEIGHT` | `BORDER` |
| Phyllotaxy | `Phyllotaxy`, `phyllotaxy`, `PHYLLOTAXY` | Fallback insertion azimuth when `XInsertionAngle` is missing | `0` |

First matching alias wins.

## 2. Stage Order and Semantics

Reconstruction applies stages in this order:

1. Translation / topology base frame.
2. Insertion angles + insertion mode offset.
3. Azimuth/Elevation world orientation override.
4. Orthotropy/StiffnessAngle bending.
5. DeviationAngle world rotation.
6. Euler stage.
7. Projection stage (`NormalUp`, then `Plagiotropy`).

Key rules:

- `StiffnessAngle` takes precedence over `Orthotropy`.
- `OrientationReset=true` resets orientation basis to the AMAP base orientation for that node before insertion/euler stages.
- If both projection flags are enabled, `NormalUp` is applied before `Plagiotropy`.
- Explicit translation attributes keep the node position explicit; topology-based placement is used only when `XX/YY/ZZ` are absent.

## 3. Insertion Angles vs Euler Angles

- Insertion angles (`X/Y/ZInsertionAngle`) control how an organ is attached to its bearer.
- Euler angles (`X/Y/ZEuler`) are post-insertion local pose refinements.

So AMAP-like usage is:

1. Use insertion angles for branching/phyllotactic orientation.
2. Use Euler angles for local tuning (roll, twist, small corrections).

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

### 6.1 `InsertionMode`: `CENTER` vs `WIDTH` vs `HEIGHT`

!!! details "Code: compare insertion mode effects"
    ```julia
    using PlantGeom
    using MultiScaleTreeGraph
    using GeometryBasics
    using StaticArrays
    using LinearAlgebra

    tri = GeometryBasics.TriangleFace{Int}
    stem_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(Point(0, 0, 0), Point(1, 0, 0), 0.5),
    )
    leaf_mesh = GeometryBasics.Mesh(
        [Point(0, -0.1, 0), Point(0, 0.1, 0), Point(1, 0, 0)],
        [tri(1, 2, 3)],
    )
    ref_meshes = Dict("Internode" => RefMesh("Stem", stem_mesh), "Leaf" => RefMesh("Leaf", leaf_mesh))
    conv = default_amap_geometry_convention()

    p0 = SVector{3,Float64}(0, 0, 0)
    p1 = SVector{3,Float64}(1, 0, 0)

    function make_small_mtg()
        mtg = Node(NodeMTG("/", "Plant", 1, 1))
        internode = Node(mtg, NodeMTG("/", "Internode", 1, 2))
        leaf = Node(internode, NodeMTG("+", "Leaf", 1, 2))

        internode[:Length] = 0.3
        internode[:Width] = 0.08
        internode[:Thickness] = 0.04
        internode[:TopWidth] = 0.10
        internode[:TopHeight] = 0.04

        leaf[:Length] = 0.2
        leaf[:Width] = 0.1
        leaf[:Thickness] = 0.002
        leaf[:YInsertionAngle] = 55.0

        return mtg, internode, leaf
    end

    function leaf_offset_components(mode)
        mtg, internode, leaf = make_small_mtg()
        leaf[:InsertionMode] = mode
        set_geometry_from_attributes!(mtg, ref_meshes; convention=conv)

        top = SVector{3,Float64}(internode[:geometry].transformation(p1))
        base = SVector{3,Float64}(internode[:geometry].transformation(p0))
        ypt = SVector{3,Float64}(internode[:geometry].transformation(SVector(0.0, 1.0, 0.0)))
        zpt = SVector{3,Float64}(internode[:geometry].transformation(SVector(0.0, 0.0, 1.0)))
        leaf_base = SVector{3,Float64}(leaf[:geometry].transformation(p0))

        width_axis = normalize(ypt - base)
        height_axis = normalize(zpt - base)
        delta = leaf_base - top

        (
            width_component = dot(delta, width_axis),
            height_component = dot(delta, height_axis),
            norm = norm(delta),
        )
    end

    for mode in ("CENTER", "WIDTH", "HEIGHT")
        println(mode, " => ", leaf_offset_components(mode))
    end
    ```

### 6.2 `verticil_mode`: sibling spread when `XInsertionAngle` is missing

!!! details "Code: compare `verticil_mode=:none` and `:rotation360`"
    ```julia
    using PlantGeom
    using MultiScaleTreeGraph
    using GeometryBasics
    using StaticArrays
    using LinearAlgebra

    tri = GeometryBasics.TriangleFace{Int}
    stem_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(Point(0, 0, 0), Point(1, 0, 0), 0.5),
    )
    leaf_mesh = GeometryBasics.Mesh(
        [Point(0, -0.1, 0), Point(0, 0.1, 0), Point(1, 0, 0)],
        [tri(1, 2, 3)],
    )
    ref_meshes = Dict("Internode" => RefMesh("Stem", stem_mesh), "Leaf" => RefMesh("Leaf", leaf_mesh))
    conv = default_amap_geometry_convention()

    p0 = SVector{3,Float64}(0, 0, 0)
    y0 = SVector{3,Float64}(0, 1, 0)

    mtg = Node(NodeMTG("/", "Plant", 1, 1))
    bearer = Node(mtg, NodeMTG("/", "Internode", 1, 2))
    leaf_a = Node(bearer, NodeMTG("+", "Leaf", 1, 2))
    leaf_b = Node(bearer, NodeMTG("+", "Leaf", 2, 2))

    bearer[:Length] = 0.3
    bearer[:Width] = 0.06
    bearer[:Thickness] = 0.04

    for leaf in (leaf_a, leaf_b)
        leaf[:Length] = 0.2
        leaf[:Width] = 0.1
        leaf[:Thickness] = 0.002
        leaf[:YInsertionAngle] = 55.0
        leaf[:Phyllotaxy] = 30.0
        leaf[:InsertionMode] = "CENTER"
        # no XInsertionAngle on purpose
    end

    function leaf_secondary_dot(mode)
        reconstruct_geometry_from_attributes!(mtg, ref_meshes; convention=conv, verticil_mode=mode)
        y_a = normalize(
            SVector{3,Float64}(leaf_a[:geometry].transformation(y0)) -
            SVector{3,Float64}(leaf_a[:geometry].transformation(p0)),
        )
        y_b = normalize(
            SVector{3,Float64}(leaf_b[:geometry].transformation(y0)) -
            SVector{3,Float64}(leaf_b[:geometry].transformation(p0)),
        )
        dot(y_a, y_b)
    end

    println(":none        => ", leaf_secondary_dot(:none))
    println(":rotation360 => ", leaf_secondary_dot(:rotation360))
    ```

### 6.3 Order-map overrides (`:override` vs `:missing_only`)

!!! details "Code: compare order override modes"
    ```julia
    using PlantGeom
    using MultiScaleTreeGraph

    mtg = Node(NodeMTG("/", "Plant", 1, 1))
    i = Node(mtg, NodeMTG("/", "Internode", 1, 2))
    l = Node(i, NodeMTG("+", "Leaf", 1, 2))

    i[:Length] = 0.3
    i[:Width] = 0.08
    i[:Thickness] = 0.04

    l[:Length] = 0.2
    l[:Width] = 0.1
    l[:Thickness] = 0.002
    l[:YInsertionAngle] = 15.0

    amap_override = AmapReconstructionOptions(
        insertion_y_by_order=Dict(2 => 60.0),
        order_override_mode=:override,
    )

    amap_missing_only = AmapReconstructionOptions(
        insertion_y_by_order=Dict(2 => 60.0),
        order_override_mode=:missing_only,
    )

    # :override -> uses 60.0
    # :missing_only -> keeps 15.0 because attribute already exists
    ```
