# AMAP Quickstart

PlantGeom now uses the AMAP core reconstruction profile by default in
`set_geometry_from_attributes!` and `reconstruct_geometry_from_attributes!`.

```@setup amapquick
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics
using Colors
using CairoMakie

CairoMakie.activate!()

const Tri = GeometryBasics.TriangleFace{Int}

function cylinder_mesh_x(radius=0.5, length=1.0)
    GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(length, 0.0, 0.0),
            radius,
        ),
    )
end

function leaf_mesh_x()
    GeometryBasics.Mesh(
        [
            Point(0.0, -0.05, 0.0),
            Point(0.0, 0.05, 0.0),
            Point(0.2, 0.0, 0.0),
            Point(1.2, 0.0, 0.0),
            Point(0.7, -0.45, 0.0),
            Point(0.7, 0.45, 0.0),
        ],
        Tri[
            Tri(1, 2, 3),
            Tri(3, 5, 4),
            Tri(3, 6, 4),
        ],
    )
end

ref_meshes = Dict(
    "Internode" => RefMesh("Stem", cylinder_mesh_x(0.5, 1.0), RGB(0.55, 0.45, 0.35)),
    "Leaf" => RefMesh("Leaf", leaf_mesh_x(), RGB(0.1, 0.5, 0.2)),
)
```

## 1. Load MTG + Reconstruct

```@example amapquick
mtg_file = joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg")
mtg = read_mtg(mtg_file)

set_geometry_from_attributes!(
    mtg,
    ref_meshes;
    convention=default_amap_geometry_convention(),
)

length(descendants(mtg, :geometry; ignore_nothing=true, self=true))
```

```@example amapquick
plantviz(mtg, color=Dict("Stem" => :tan4, "Leaf" => :forestgreen))
```

## 2. Customize AMAP Options

```@example amapquick
mtg_default = read_mtg(mtg_file)
mtg_custom = read_mtg(mtg_file)

set_geometry_from_attributes!(
    mtg_default,
    ref_meshes;
    convention=default_amap_geometry_convention(),
)

amap_custom = AmapReconstructionOptions(
    order_override_mode=:missing_only,
    phyllotaxy_by_order=Dict(2 => 137.5),
)

set_geometry_from_attributes!(
    mtg_custom,
    ref_meshes;
    convention=default_amap_geometry_convention(),
    amap_options=amap_custom,
)

(
    default=length(descendants(mtg_default, :geometry; ignore_nothing=true, self=true)),
    custom=length(descendants(mtg_custom, :geometry; ignore_nothing=true, self=true)),
)
```

Both calls use AMAP stages. The second one only customizes option values.

!!! details "Code to reproduce this page figures"
    ```julia
    using PlantGeom
    using MultiScaleTreeGraph
    using GeometryBasics
    using Colors
    using CairoMakie

    CairoMakie.activate!()

    const Tri = GeometryBasics.TriangleFace{Int}

    function cylinder_mesh_x(radius=0.5, length=1.0)
        GeometryBasics.mesh(
            GeometryBasics.Cylinder(
                Point(0.0, 0.0, 0.0),
                Point(length, 0.0, 0.0),
                radius,
            ),
        )
    end

    function leaf_mesh_x()
        GeometryBasics.Mesh(
            [
                Point(0.0, -0.05, 0.0),
                Point(0.0, 0.05, 0.0),
                Point(0.2, 0.0, 0.0),
                Point(1.2, 0.0, 0.0),
                Point(0.7, -0.45, 0.0),
                Point(0.7, 0.45, 0.0),
            ],
            Tri[
                Tri(1, 2, 3),
                Tri(3, 5, 4),
                Tri(3, 6, 4),
            ],
        )
    end

    ref_meshes = Dict(
        "Internode" => RefMesh("Stem", cylinder_mesh_x(0.5, 1.0), RGB(0.55, 0.45, 0.35)),
        "Leaf" => RefMesh("Leaf", leaf_mesh_x(), RGB(0.1, 0.5, 0.2)),
    )

    mtg_file = joinpath(pkgdir(PlantGeom), "test", "files", "reconstruction_standard.mtg")
    mtg = read_mtg(mtg_file)

    set_geometry_from_attributes!(
        mtg,
        ref_meshes;
        convention=default_amap_geometry_convention(),
    )

    plantviz(mtg, color=Dict("Stem" => :tan4, "Leaf" => :forestgreen))
    ```
