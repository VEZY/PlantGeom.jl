# Quickstart: Grow a Plant

!!! info "Page Info"
    - **Audience:** Beginner
    - **Prerequisites:** basic Julia, `PlantGeom`, `MultiScaleTreeGraph`, `CairoMakie`
    - **Time:** 10 minutes
    - **Output:** Loop-driven growth with explicit geometry rebuild

```@setup gs_grow
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics
using Colors
using CairoMakie

CairoMakie.activate!()

stem_ref = RefMesh(
    "stem",
    GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            0.5,
        ),
    ),
    RGB(0.48, 0.36, 0.25),
)

blade_ref = lamina_refmesh(
    "blade";
    length=1.0,
    max_width=1.0,
    n_long=36,
    n_half=7,
    material=RGB(0.19, 0.61, 0.29),
)

prototypes = Dict(
    :Internode => RefMeshPrototype(stem_ref),
    :Leaf => PointMapPrototype(
        blade_ref;
        defaults=(base_angle_deg=42.0, bend=0.30, tip_drop=0.08),
        intrinsic_shape=params -> LaminaMidribMap(
            base_angle_deg=params.base_angle_deg,
            bend=params.bend,
            tip_drop=params.tip_drop,
        ),
    ),
)
```

## What You'll Get

```@example gs_grow
plant = let
    p = Node(NodeMTG(:/, :Plant, 1, 1))
    axis = emit_internode!(p; index=1, link=:/, length=0.18, width=0.022)

    step = 2
    while step <= 8
        axis = emit_internode!(
            axis;
            index=step,
            length=0.17 * 0.95^(step - 2),
            width=0.021 * 0.93^(step - 2),
            y_euler=2.0 * sin(step / 3),
        )
        emit_leaf!(
            axis;
            index=step,
            offset=0.80 * axis[:Length],
            length=0.22 + 0.018 * step,
            width=0.032 + 0.003 * step,
            thickness=0.010 + 0.0015 * step,
            phyllotaxy=isodd(step) ? 0.0 : 180.0,
            y_insertion_angle=54.0,
            prototype=:Leaf,
            prototype_overrides=(bend=0.12 + 0.06 * step, tip_drop=0.02 * step),
        )
        step += 1
    end

    rebuild_geometry!(p, prototypes)
    p
end

plantviz(plant, figure=(size=(980, 700),))
```

## What Each Stage Does

| Stage | What happens |
| --- | --- |
| `emit_internode!` | creates a new stem node and writes growth attributes |
| `emit_leaf!` | creates a leaf node attached to current stem node |
| `prototype_overrides` | changes shape parameters per leaf instance |
| `rebuild_geometry!` | materializes all node geometry once at the end |
| `plantviz(...)` | renders the generated plant |

## Copy-Paste Example

```julia
using PlantGeom, MultiScaleTreeGraph, GeometryBasics, Colors, CairoMakie
CairoMakie.activate!()

stem = RefMesh("stem", GeometryBasics.mesh(GeometryBasics.Cylinder(Point(0,0,0), Point(1,0,0), 0.5)), RGB(0.48, 0.36, 0.25))
leaf = lamina_refmesh("leaf"; length=1.0, max_width=1.0, material=RGB(0.19, 0.61, 0.29))
prototypes = Dict(:Internode => RefMeshPrototype(stem), :Leaf => PointMapPrototype(leaf; defaults=(base_angle_deg=42.0, bend=0.3, tip_drop=0.08), intrinsic_shape=p -> LaminaMidribMap(base_angle_deg=p.base_angle_deg, bend=p.bend, tip_drop=p.tip_drop)))

plant = Node(NodeMTG(:/, :Plant, 1, 1)); axis = emit_internode!(plant; link=:/, length=0.18, width=0.022)
for i in 2:8
    axis = emit_internode!(axis; index=i, length=0.17 * 0.95^(i - 2), width=0.021 * 0.93^(i - 2))
    emit_leaf!(axis; index=i, offset=0.8 * axis[:Length], length=0.22 + 0.018i, width=0.032 + 0.003i, thickness=0.01 + 0.0015i, phyllotaxy=isodd(i) ? 0.0 : 180.0, y_insertion_angle=54.0, prototype=:Leaf, prototype_overrides=(bend=0.12 + 0.06i, tip_drop=0.02i))
end
rebuild_geometry!(plant, prototypes)
plantviz(plant, figure=(size=(980, 700),))
```

## Why It Works

The growth loop only updates topology and node attributes.  
`rebuild_geometry!` is called once, so geometry generation stays explicit and easy to debug.

!!! details "Troubleshooting"
    - If your leaf shapes do not change, verify the leaf prototype key and override names.
    - If plotting is slow, keep geometry rebuild explicit and lower its frequency.

## Next Step

Go to [`Workflow Tutorial`](../geometry/building_plant_models.md) for a complete build-and-simulate workflow and links to advanced geometry and AMAP references.
