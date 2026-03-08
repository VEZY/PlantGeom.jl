# Quickstart: Reconstruct a Plant

!!! info "Page Info"
    - **Audience:** Beginner
    - **Prerequisites:** basic Julia, `PlantGeom`, `MultiScaleTreeGraph`, `CairoMakie`
    - **Time:** 8 minutes
    - **Output:** Reconstructed 3D plant from attribute-driven MTG

```@setup gs_reconstruct
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics
using Colors
using CairoMakie

CairoMakie.activate!()

const Tri = GeometryBasics.TriangleFace{Int}

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

leaf_ref = RefMesh(
    "leaf",
    GeometryBasics.Mesh(
        [
            Point(0.0, -0.08, 0.0),
            Point(0.0, 0.08, 0.0),
            Point(0.24, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            Point(0.6, -0.28, 0.0),
            Point(0.6, 0.28, 0.0),
        ],
        Tri[
            Tri(1, 2, 3),
            Tri(3, 5, 4),
            Tri(3, 6, 4),
        ],
    ),
    RGB(0.19, 0.62, 0.30),
)

prototypes = Dict(
    :Internode => RefMeshPrototype(stem_ref),
    :Leaf => RefMeshPrototype(leaf_ref),
)
```

## What You'll Get

```@example gs_reconstruct
mtg_file = joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg")
mtg = read_mtg(mtg_file)

set_geometry_from_attributes!(
    mtg,
    prototypes;
    convention=default_amap_geometry_convention(),
)

plantviz(mtg, figure=(size=(920, 640),))
```

## Copy-Paste Example

```julia
using PlantGeom, MultiScaleTreeGraph, GeometryBasics, Colors, CairoMakie
CairoMakie.activate!()

stem = RefMesh("stem", GeometryBasics.mesh(GeometryBasics.Cylinder(Point(0,0,0), Point(1,0,0), 0.5)), RGB(0.5, 0.38, 0.26))
leaf = lamina_refmesh("leaf"; length=1.0, max_width=1.0, material=RGB(0.19, 0.62, 0.30))
prototypes = Dict(:Internode => RefMeshPrototype(stem), :Leaf => RefMeshPrototype(leaf))

mtg = read_mtg(joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg"))
set_geometry_from_attributes!(mtg, prototypes; convention=default_amap_geometry_convention())
plantviz(mtg, figure=(size=(920, 640),))
```

## Why It Works

`set_geometry_from_attributes!` resolves node size/orientation attributes (`Length`, `Width`, insertion/euler angles) and instantiates node geometry from your prototypes.

## Next Step

Go to [`Quickstart: Grow a Plant`](quickstart_grow.md) to generate structure in a Julia loop and rebuild geometry explicitly.
