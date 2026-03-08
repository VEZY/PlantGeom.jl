# AMAP Quickstart

!!! info "Page Info"
    - **Audience:** Intermediate
    - **Prerequisites:** completed beginner reconstruction quickstart
    - **Time:** 12 minutes
    - **Output:** AMAP-profile reconstruction in PlantGeom

PlantGeom now uses the AMAP core reconstruction profile by default in
`set_geometry_from_attributes!` and `reconstruct_geometry_from_attributes!`.

If you need help choosing explicit-coordinate behavior (`explicit_coordinate_mode`),
start with the [`AMAP Reconstruction Decision Guide`](amap_reconstruction_decision_guide.md).

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

!!! details "Content of `reconstruction_standard.mtg`"
    ```text
    CODE:	FORM-A
    
    CLASSES:
    SYMBOL	SCALE	DECOMPOSITION	INDEXATION	DEFINITION
    Plant	1	FREE	FREE	IMPLICIT
    Internode	2	FREE	FREE	IMPLICIT
    Leaf	2	FREE	FREE	IMPLICIT
    
    DESCRIPTION:
    LEFT	RIGHT	RELTYPE	MAX
    
    FEATURES:
    NAME	TYPE
    Thickness	REAL
    Length	REAL
    Width	REAL
    YEuler	REAL
    XEuler	REAL
    XInsertionAngle	REAL
    YInsertionAngle	REAL
    Offset	REAL
    BorderInsertionOffset	REAL
    
    MTG:
    ENTITY-CODE		Thickness	Length	Width	YEuler	XEuler	XInsertionAngle	YInsertionAngle	Offset	BorderInsertionOffset
    /Plant1										
    ^/Internode1		0.035	0.28	0.035	1.438276615812609					
    	+Leaf1	0.002	0.235	0.116		-18.0	45.0	53.68294196961579	0.2296	0.0175
    ^<Internode2		0.03325	0.2632	0.03325	2.5244129544236893					
    	+Leaf2	0.002	0.25	0.122		-18.0	135.0	53.81859485365136	0.215824	0.016625
    ^<Internode3		0.031587500000000004	0.24740800000000002	0.031587500000000004	2.9924849598121632					
    	+Leaf3	0.002	0.265	0.128		-18.0	225.0	52.28224001611974	0.20287456	0.015793750000000002
    ^<Internode4		0.030008125	0.23256352	0.030008125	2.727892280477045					
    ^+Leaf4		0.002	0.28	0.134		-18.0	315.0	50.48639500938415	0.1907020864	0.0150040625
    ```

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
    order_override_mode=:override,
    insertion_y_by_order=Dict(2 => 25.0),
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

Both calls use AMAP stages. The second one customizes option values and visibly changes leaf insertion.

`reconstruction_standard.mtg` already defines `XInsertionAngle` on leaves, so
`phyllotaxy_by_order` would not change this specific fixture unless `XInsertionAngle` is missing.

```@example amapquick
plantviz(mtg_custom, color=Dict("Stem" => :tan4, "Leaf" => :darkgreen))
```

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

    mtg_custom = read_mtg(mtg_file)
    amap_custom = AmapReconstructionOptions(
        order_override_mode=:override,
        insertion_y_by_order=Dict(2 => 25.0),
    )

    set_geometry_from_attributes!(
        mtg_custom,
        ref_meshes;
        convention=default_amap_geometry_convention(),
        amap_options=amap_custom,
    )

    plantviz(mtg_custom, color=Dict("Stem" => :tan4, "Leaf" => :darkgreen))
    ```
