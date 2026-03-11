# MTG Reconstruction Tutorial

!!! info "Page Info"
    - **Audience:** Beginner to Intermediate
    - **Prerequisites:** beginner reconstruction quickstart
    - **Time:** 12 minutes
    - **Output:** First automatic 3D reconstruction from MTG measurements

This page explains how to reconstruct a plant from an MTG that contains:
- topology (`:<`, `:+`, `:/`)
- measurements such as `Length`, `Width`, insertion angles, Euler angles
- optionally explicit coordinates

The two reconstruction functions you will use are:

```julia
set_geometry_from_attributes!(mtg, prototypes; ...)
reconstruct_geometry_from_attributes!(mtg, prototypes; ...)
```

For most users, `set_geometry_from_attributes!` is the right starting point.

## What You Need in the MTG

You do **not** need every possible AMAP variable to begin.

### Minimum useful measurement set

| Column | Meaning | Why it matters |
| --- | --- | --- |
| `Length` | organ length | scales the organ along its main axis |
| `Width` | organ width | scales the organ laterally |
| `Thickness` | organ thickness | optional but useful for non-flat organs |

### Standard set for topology-based plant reconstruction

| Column | Meaning |
| --- | --- |
| `Length`, `Width`, `Thickness` | organ size |
| `XInsertionAngle`, `YInsertionAngle`, `ZInsertionAngle` | orientation at attachment |
| `XEuler`, `YEuler`, `ZEuler` | extra local rotation after insertion |
| `Offset` | where a `:+` organ is attached along its bearer |
| `BorderInsertionOffset` | lateral shift on the bearer cross-section |

### Optional explicit-coordinate set

| Column | Meaning |
| --- | --- |
| `XX`, `YY`, `ZZ` | explicit node start position |
| `EndX`, `EndY`, `EndZ` | explicit node end position |

If you measure explicit coordinates, read
[Explicit Coordinates: Which Option Should I Use?](@ref)
after this tutorial.

```@setup amapquick
using PlantGeom
using MultiScaleTreeGraph
using Colors
using CairoMakie
using GeometryBasics
```

To run this tutorial, you need to install and import the following packages:

```julia
using PlantGeom
using MultiScaleTreeGraph
using Colors
using CairoMakie
using GeometryBasics
```

## 1. Load the MTG

The example file used here is `test/files/reconstruction_standard.mtg`.

```@example amapquick
mtg_file = joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg")
mtg = read_mtg(mtg_file)
```

The MTG file is as follows:

```@example amapquick
mtg_file = joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg") # hide
open(mtg_file, "r") do f # hide
    content = read(f, String) ## hide
    println(content) # hide
end # hide
```

## 2. Define Organ Prototypes

PlantGeom needs one geometry prototype per organ type.  
Here we define:

- one cylindrical prototype for internodes
- one flat prototype for leaves

These prototypes are unit-sized. MTG columns such as `Length` and `Width` will scale them during reconstruction.

```@example amapquick
internode_refmesh = RefMesh(
    "Stem",
    GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            0.5,
        ),
    ),
    RGB(0.55, 0.45, 0.35),
)

leaf_refmesh = RefMesh(
    "Leaf",
    GeometryBasics.Mesh(
        [
            Point(0.0, -0.05, 0.0),
            Point(0.0, 0.05, 0.0),
            Point(0.2, 0.0, 0.0),
            Point(1.2, 0.0, 0.0),
            Point(0.7, -0.45, 0.0),
            Point(0.7, 0.45, 0.0),
        ],
        [
            TriangleFace(1, 2, 3),
            TriangleFace(3, 5, 4),
            TriangleFace(3, 6, 4),
        ],
    ),
    RGB(0.10, 0.50, 0.20),
)

prototypes = Dict(
    :Internode => RefMeshPrototype(internode_refmesh),
    :Leaf => RefMeshPrototype(leaf_refmesh),
)
```

## 3. Reconstruct Geometry

Now call:

```julia
set_geometry_from_attributes!(mtg, prototypes; convention=default_amap_geometry_convention())
```

What this does:
- reads MTG columns such as `Length`, `Width`, `XInsertionAngle`, `YEuler`, ...
- interprets them with `default_amap_geometry_convention()`
- creates geometry on each node in `node[:geometry]`

```@example amapquick
set_geometry_from_attributes!(
    mtg,
    prototypes;
    convention=default_amap_geometry_convention(),
)

plantviz(mtg, color=Dict("Stem" => :tan4, "Leaf" => :forestgreen))
```

## 4. Change One Reconstruction Option

You can customize AMAP behavior with:

```julia
AmapReconstructionOptions(...)
```

and pass it as:

```julia
set_geometry_from_attributes!(...; amap_options=opts)
```

Example: make second-order organs more erect by overriding their `Y` insertion angle.

```@example amapquick
mtg_default = read_mtg(mtg_file)
mtg_custom = read_mtg(mtg_file)

set_geometry_from_attributes!(
    mtg_default,
    prototypes;
    convention=default_amap_geometry_convention(),
)

opts = AmapReconstructionOptions(
    order_override_mode=:override,
    insertion_y_by_order=Dict(2 => 25.0),
)

set_geometry_from_attributes!(
    mtg_custom,
    prototypes;
    convention=default_amap_geometry_convention(),
    amap_options=opts,
)
nothing # hide
```

```@example amapquick
f = Figure(size=(980, 420))
ax1 = Axis3(f[1, 1], title="Default", aspect=:data)
plantviz!(ax1, mtg_default, color=Dict("Stem" => :tan4, "Leaf" => :forestgreen))
ax2 = Axis3(f[1, 2], title="Custom option", aspect=:data)
plantviz!(ax2, mtg_custom, color=Dict("Stem" => :tan4, "Leaf" => :darkgreen))
f
```

## What To Measure First

If you are building your own measurement workflow, a good order is:

1. `Length`, `Width`, `Thickness`
2. `Offset`
3. insertion angles (`XInsertionAngle`, `YInsertionAngle`, `ZInsertionAngle`)
4. Euler corrections only if needed
5. explicit coordinates only if your data source already provides them

This gives a useful reconstruction without measuring every advanced AMAP variable.

## Where To Go Next

- To decide which **explicit coordinate mode** to use:
  [Explicit Coordinates: Which Option Should I Use?](@ref)
- To see the full list of MTG columns you can define:
  [AMAP Conventions Reference](@ref)

!!! details "Troubleshooting"
    - If nothing appears, check that your MTG contains at least `Length` and `Width` on the organs you want to reconstruct.
    - If the organ orientation looks wrong, first verify that your prototype meshes are authored with length along local `+X`.
    - If your column names differ from the defaults, define a custom `GeometryConvention`.
