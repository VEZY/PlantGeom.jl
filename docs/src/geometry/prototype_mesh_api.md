# Prototype-Centric Mesh API

!!! info "Page Info"
    - **Audience:** Intermediate to Advanced
    - **Prerequisites:** familiarity with reconstruction and growth APIs
    - **Time:** 15 minutes
    - **Output:** Deterministic prototype realization model and parameter override strategy (Level 3 concept page)

If you are new to PlantGeom, start with:
- [`Quickstart: Reconstruct a Plant`](../getting_started/quickstart_reconstruct.md)
- [`Quickstart: Grow a Plant`](../getting_started/quickstart_grow.md)

PlantGeom now supports a unified prototype pipeline for reconstruction:

1. resolve a mesh prototype
2. resolve parameters (call overrides > node overrides > node attrs > defaults)
3. build local prototype geometry
4. apply intrinsic shape maps
5. apply size from node attributes (`Length`, `Width`, `Thickness`)
6. apply physical deformation
7. apply pose (rotation + translation)

This keeps geometry ordering deterministic and avoids user mistakes about scaling order.

## Prototype types

- `RefMeshPrototype`: normalized reference mesh, scaled by node size attributes.
- `PointMapPrototype`: normalized mesh + parametric point-map pipeline.
- `ExtrusionPrototype`: parametric extrusion builder.
- `RawMeshPrototype`: imported mesh as-is (size attrs are ignored; pose still applies).

Use `available_parameters(proto)` to inspect supported parameters, and
`effective_parameters(node, proto; overrides=...)` to inspect resolved values.

## High-level reconstruction

```julia
prototypes = Dict(
    :Internode => RefMeshPrototype(stem_ref),
    :Leaf => PointMapPrototype(
        leaf_ref;
        defaults=(bend=0.25, tip_drop=0.10),
        attr_aliases=(bend=(:bend, :Bend), tip_drop=(:tip_drop, :TipDrop)),
        intrinsic_shape=params -> LaminaMidribMap(
            base_angle_deg=38.0,
            bend=params.bend,
            tip_drop=params.tip_drop,
        ),
    ),
)

leaf = emit_leaf!(
    parent;
    prototype=:Leaf,
    prototype_overrides=(bend=0.45,),
    length=0.30,
    width=0.05,
)

rebuild_geometry!(mtg, prototypes; prototype_selector=nothing)
```

## Low-level escape hatch (unchanged)

You can still assign geometry directly for debugging/manual control:

```julia
node[:geometry] = Geometry(
    ref_mesh=leaf_ref,
    transformation=compose(Translation(0.0, 0.0, 0.8), LinearMap(RotZ(pi/4))),
)

node[:geometry] = PointMappedGeometry(
    leaf_ref,
    compose_point_maps(
        LaminaTwistRollMap(tip_twist_deg=12.0, roll_strength=0.25),
        LaminaMidribMap(base_angle_deg=42.0, bend=0.40, tip_drop=0.12),
    ),
)

node[:geometry] = ExtrudedTubeGeometry(path; n_sides=12, radius=0.02)
```

## Imported mesh as-is

If you want to keep imported mesh dimensions exactly as in file:

```julia
prototypes = Dict(:Leaf => RawMeshPrototype(imported_refmesh))
rebuild_geometry!(mtg, prototypes)
```

`Length`, `Width`, and `Thickness` are ignored for `RawMeshPrototype` by design.
