# Procedural / Extrusion Geometry

PlantGeom supports two complementary geometry workflows:

- shared geometry with `RefMesh` + `Geometry(ref_mesh=..., transformation=...)`
- per-node procedural geometry with `ExtrudedTubeGeometry` and extrusion helpers

If you already know the `RefMesh` workflow, this page is the extrusion counterpart.

## When to Use Which Workflow

Use `RefMesh` + `Geometry` when:

- many nodes share the same base organ mesh
- only node transform differs (scale/rotation/translation)
- you want the classic OPF-style "instantiate once, transform many" pattern

Use procedural extrusion when:

- each axis/organ needs its own path or profile
- geometry is easier to define from centerlines and section evolution
- you want to build geometry directly from node parameters

## Node-Level Procedural Geometry

`ExtrudedTubeGeometry` is a procedural node geometry source. It does not point to
an existing `RefMesh`; the local mesh is generated from path/section parameters.

```julia
using PlantGeom
using MultiScaleTreeGraph
using Colors
using GeometryBasics

mtg = Node(NodeMTG("/", "Plant", 1, 1))
axis = Node(mtg, NodeMTG("/", "Internode", 1, 2))

axis[:geometry] = ExtrudedTubeGeometry(
    [
        Point(0.0, 0.0, 0.0),
        Point(0.3, 0.02, 0.01),
        Point(0.7, 0.07, 0.04),
        Point(1.1, 0.12, 0.06),
    ];
    n_sides=16,
    radius=0.045,
    radii=[1.0, 0.9, 0.75, 0.6],  # taper
    torsion=false,
    cap_ends=true,
    material=RGB(0.45, 0.35, 0.25),
    transformation=PlantGeom.Translation(0.2, 0.0, 0.0),
)
```

Main parameters:

- `path`: centerline points
- `n_sides`, `radius`: base circular section
- `radii`: isotropic scaling along the path
- `widths`, `heights`: anisotropic scaling (override `radii` when provided)
- `path_normals`, `torsion`: local frame control
- `cap_ends`: optional end caps for closed circular sections
- `transformation`: post-extrusion transform

## Reusable Extrusion as `RefMesh`

If many nodes share the same procedural shape, generate it once and wrap it in a
`RefMesh`, then keep using classic `Geometry`.

```julia
leaf_section = leaflet_midrib_profile(; lamina_angle_deg=42.0, scale=0.5)
leaf_path = [Point(0.0, 0.0, 0.0), Point(0.5, 0.0, 0.08), Point(1.0, 0.0, 0.12)]

leaf_ref = extrude_profile_refmesh(
    "leaf_extruded",
    leaf_section,
    leaf_path;
    widths=[1.0, 0.8, 0.5],
    heights=[1.0, 0.9, 0.7],
    torsion=true,
    close_section=false,
    cap_ends=false,
    material=RGB(0.15, 0.55, 0.25),
)
```

You can also build mesh first (`extrude_profile_mesh`, `extrude_tube_mesh`) then
manually wrap it with `RefMesh(...)`.

## Path, Profile, and Lathe Helpers

Extrusion helper APIs:

- section profiles: `circle_section_profile`, `leaflet_midrib_profile`
- path interpolation: `extrusion_make_path`, `extrusion_make_spline`
- scalar interpolation: `extrusion_make_interpolation`
- AMAP-like curve helper: `extrusion_make_curve`
- lathe helpers: `lathe_mesh`, `lathe_refmesh`, `lathe_gen_mesh`, `lathe_gen_refmesh`

These are useful when you have sparse key points/values and need smooth geometry.

## Recommended Pattern

- Repeated geometry: use cached procedural `RefMesh` constructors.
- Unique per-node geometry: use `ExtrudedTubeGeometry` directly on nodes.
- In both cases, render with the same `plantviz` pipeline.

See also:

- [`Reference Meshes`](refmesh.md)
- [`Building Plant Models`](building_plant_models.md)
- [`AMAPStudio Parity Matrix`](amap_parity_matrix.md)
