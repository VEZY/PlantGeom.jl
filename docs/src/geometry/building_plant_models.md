# Build & Simulate Plants

!!! info "Page Info"
    - **Audience:** Beginner to Intermediate
    - **Prerequisites:** completed the Getting Started quickstarts
    - **Time:** 20 minutes
    - **Output:** End-to-end workflow (reconstruct from attributes, then loop-driven growth)

This page is the practical bridge between quickstarts and advanced concepts.

## Choose a Strategy

| Situation | Recommended workflow | Why |
| --- | --- | --- |
| You already have measured attributes in an `.mtg` | Workflow A | fastest path to a first reconstruction |
| You want dynamic growth over time | Workflow B | explicit, debuggable simulation loop |
| You need strict AMAP behavior controls | AMAP pages | complete option set and decision guidance |

## If You Just Want X, Go Here

- Attribute-based reconstruction from measured MTG data:
  [`Quickstart: Reconstruct a Plant`](../getting_started/quickstart_reconstruct.md)
- Loop-driven growth with explicit rebuild:
  [`Quickstart: Grow a Plant`](../getting_started/quickstart_grow.md)
- AMAP options and conventions:
  [`AMAP Quickstart`](amap_quickstart.md) and [`AMAP Conventions Reference`](amap_conventions_reference.md)
- Low-level geometry control:
  [`Prototype Mesh API`](prototype_mesh_api.md) and [`Procedural / Extrusion Geometry`](procedural_geometry.md)

```@setup buildsim
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
    RGB(0.50, 0.38, 0.26),
)

leaf_ref = lamina_refmesh(
    "leaf";
    length=1.0,
    max_width=1.0,
    n_long=36,
    n_half=7,
    material=RGB(0.19, 0.61, 0.29),
)

prototypes = Dict(
    :Internode => RefMeshPrototype(stem_ref),
    :Leaf => PointMapPrototype(
        leaf_ref;
        defaults=(base_angle_deg=44.0, bend=0.25, tip_drop=0.06),
        intrinsic_shape=params -> LaminaMidribMap(
            base_angle_deg=params.base_angle_deg,
            bend=params.bend,
            tip_drop=params.tip_drop,
        ),
    ),
)
```

## Workflow A: Reconstruct from Existing MTG Attributes

```@example buildsim
mtg = read_mtg(joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg"))

set_geometry_from_attributes!(
    mtg,
    prototypes;
    convention=default_amap_geometry_convention(),
)

plantviz(mtg, figure=(size=(920, 640),))
```

Why this is useful:
- good starting point when data already has `Length`, `Width`, insertion/euler attributes
- deterministic and easy to compare with AMAP-style conventions

## Workflow B: Grow Structure in Julia, Rebuild on Demand

```@example buildsim
plant = let
    p = Node(NodeMTG(:/, :Plant, 1, 1))
    axis = emit_internode!(p; index=1, link=:/, length=0.18, width=0.022)

    for rank in 2:8
        axis = emit_internode!(
            axis;
            index=rank,
            length=0.17 * 0.95^(rank - 2),
            width=0.021 * 0.93^(rank - 2),
        )

        emit_leaf!(
            axis;
            index=rank,
            offset=0.80 * axis[:Length],
            length=0.21 + 0.02 * rank,
            width=0.032 + 0.003 * rank,
            thickness=0.010 + 0.0015 * rank,
            phyllotaxy=isodd(rank) ? 0.0 : 180.0,
            y_insertion_angle=54.0,
            prototype=:Leaf,
            prototype_overrides=(bend=0.10 + 0.06 * rank, tip_drop=0.02 * rank),
        )
    end

    rebuild_geometry!(p, prototypes)
    p
end

plantviz(plant, figure=(size=(980, 700),))
```

Why this is useful:
- topology/attributes stay explicit and debuggable
- you choose rebuild cadence for performance

!!! details "Where the deep technical details moved"
    - AMAP coordinate delegates, insertion modes, and alias tables:
      [`AMAP Conventions Reference`](amap_conventions_reference.md)
    - Explicit-coordinate mode selection:
      [`AMAP Reconstruction Decision Guide`](amap_reconstruction_decision_guide.md)
    - Prototype realization order and override precedence:
      [`Prototype Mesh API`](prototype_mesh_api.md)
    - Manual low-level geometry assignment (`Geometry`, `PointMappedGeometry`, `ExtrudedTubeGeometry`):
      [`Procedural / Extrusion Geometry`](procedural_geometry.md)
