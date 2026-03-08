# Showcase

!!! info "Page Info"
    - **Audience:** Beginner
    - **Prerequisites:** `using PlantGeom, CairoMakie`
    - **Time:** 3 minutes
    - **Output:** Full-plant 3D visualizations from existing files

If you are new to programming, you can treat this page as "copy-paste and run" first.  
You can understand details later in the quickstarts.

```@setup gs_showcase
using PlantGeom
using CairoMakie

CairoMakie.activate!()

files_dir = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files")
simple_opf = read_opf(joinpath(files_dir, "simple_plant.opf"))
coffee_opf = read_opf(joinpath(files_dir, "coffee.opf"))

include(joinpath(pkgdir(PlantGeom), "docs", "src", "getting_started", "tree_demo_helpers.jl"))
```

## What You'll Get

```@example gs_showcase
plantviz(simple_opf, figure=(size=(980, 680),))
```

```@example gs_showcase
plantviz(coffee_opf, figure=(size=(980, 720),))
```

```@example gs_showcase
tree_demo = build_demo_tree_with_growth_api()
plantviz(tree_demo, figure=(size=(980, 920),))
```

Palm generated with the VPalm module from [XPalm.jl](https://github.com/PalmStudio/XPalm.jl), managed with PlantGeom geometry, and rendered with RayMakie:

![3D palm generated with XPalm and rendered with RayMakie](https://raw.githubusercontent.com/SimonDanisch/RayDemo/refs/heads/main/Plants/plants.png)

## Copy-Paste Example

```julia
using PlantGeom, CairoMakie
CairoMakie.activate!()

files_dir = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files")
opf = read_opf(joinpath(files_dir, "coffee.opf"))
plantviz(opf, figure=(size=(980, 720),))
```

## Tree Demo Code (Growth API)

The full tree builder uses `emit_internode!`, `emit_leaf!`, explicit coordinate attributes (`XX/YY/ZZ`, `EndX/EndY/EndZ`), and one explicit `rebuild_geometry!` call with prototypes.

```julia
include(joinpath(pkgdir(PlantGeom), "docs", "src", "getting_started", "tree_demo_helpers.jl"))
tree_demo = build_demo_tree_with_growth_api()
plantviz(tree_demo, figure=(size=(980, 920),))
```

Source file used by this example:
`docs/src/getting_started/tree_demo_helpers.jl`

## Why It Works

- `read_opf` gives you topology + geometry from existing plant files.
- `build_demo_tree_with_growth_api()` shows a generated plant using explicit growth + rebuild steps.
- `plantviz` materializes and renders current node geometries in one call.

## Next Step

Go to [`Quickstart: Reconstruct a Plant`](quickstart_reconstruct.md) to reconstruct geometry from an MTG that has topology/attributes but no explicit meshes.
