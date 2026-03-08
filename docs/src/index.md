```@meta
CurrentModule = PlantGeom
```

# PlantGeom

PlantGeom lets you build, reconstruct, and visualize 3D plants from MTG topology and mesh prototypes.

## If You Just Want X, Go Here

- See impressive results immediately: [`Getting Started / Showcase`](getting_started/showcase.md)
- Reconstruct a plant from attributes: [`Quickstart: Reconstruct a Plant`](getting_started/quickstart_reconstruct.md)
- Build a plant in a Julia loop: [`Quickstart: Grow a Plant`](getting_started/quickstart_grow.md)
- Advanced geometry internals: [`Geometry Concepts (advanced)`](geometry/refmesh.md)
- AMAP conventions and parity: [`AMAP Reference`](geometry/amap_quickstart.md)

## Choose Your Workflow

| Your goal | Start here | Next |
| --- | --- | --- |
| Render an existing `.opf` file | [`Showcase`](getting_started/showcase.md) | [`3D Plant Plots`](makie_3d.md) |
| Reconstruct geometry from an `.mtg` file | [`Quickstart: Reconstruct a Plant`](getting_started/quickstart_reconstruct.md) | [`Build & Simulate Plants`](geometry/building_plant_models.md) |
| Simulate growth with explicit Julia loops | [`Quickstart: Grow a Plant`](getting_started/quickstart_grow.md) | [`Growth API`](geometry/growth_api.md) |
| Tune advanced reconstruction behavior | [`AMAP Quickstart`](geometry/amap_quickstart.md) | [`AMAP Conventions Reference`](geometry/amap_conventions_reference.md) |

```@setup home
using PlantGeom
using CairoMakie

CairoMakie.activate!()

files_dir = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files")
hero_opf = read_opf(joinpath(files_dir, "coffee.opf"))
include(joinpath(pkgdir(PlantGeom), "docs", "src", "getting_started", "tree_demo_helpers.jl"))
```

## What You'll Get

```@example home
plantviz(hero_opf, figure=(size=(980, 720),))
```

## Tree Highlight

```@example home
tree_demo = build_demo_tree_with_growth_api()
plantviz(tree_demo, figure=(size=(860, 780),))
```

## 15-Line Quickstart

```julia
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics
using Colors
using CairoMakie
CairoMakie.activate!()

mtg = read_mtg(joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg"))
stem = RefMesh("stem", GeometryBasics.mesh(GeometryBasics.Cylinder(Point(0,0,0), Point(1,0,0), 0.5)), RGB(0.5, 0.38, 0.26))
leaf = lamina_refmesh("leaf"; length=1.0, max_width=1.0, material=RGB(0.2, 0.62, 0.30))
prototypes = Dict(:Internode => RefMeshPrototype(stem), :Leaf => RefMeshPrototype(leaf))
set_geometry_from_attributes!(mtg, prototypes; convention=default_amap_geometry_convention())
plantviz(mtg, figure=(size=(900, 620),))
```

## Mini Glossary

| Term | Practical meaning |
| --- | --- |
| `Node` | one organ instance (stem segment, leaf, etc.) |
| `MTG` | graph storing topology + attributes |
| `RefMesh` | reusable unit organ mesh |
| `Prototype` | rule for turning node attributes into geometry |
| `rebuild_geometry!` | explicit geometry generation/update step |

## Learning Path

1. [`Showcase`](getting_started/showcase.md)
2. [`Quickstart: Reconstruct a Plant`](getting_started/quickstart_reconstruct.md)
3. [`Quickstart: Grow a Plant`](getting_started/quickstart_grow.md)
4. [`Build & Simulate Plants`](geometry/building_plant_models.md)
5. [`Geometry Concepts (advanced)`](geometry/prototype_mesh_api.md)
