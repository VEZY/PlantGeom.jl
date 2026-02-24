# Procedural / Extrusion Geometry

PlantGeom supports two complementary geometry workflows:

- shared geometry with `RefMesh` + `Geometry(ref_mesh=..., transformation=...)`
- per-node procedural geometry with `ExtrudedTubeGeometry` and extrusion helpers

If you already know the `RefMesh` workflow, this page is the extrusion counterpart.

```@setup procgeom
using PlantGeom
using CairoMakie
using GeometryBasics
using Colors

CairoMakie.activate!()
```

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

mtg = Node(NodeMTG(:/, :Plant, 1, 1))
axis = Node(mtg, NodeMTG(:/, :Internode, 1, 2))

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

The helpers below cover the full workflow:

- section/profile builders
- path interpolation
- scalar interpolation
- lathe mesh generation

### 1) Profile helpers

- `circle_section_profile(n_sides; radius, close_loop=true)`: circular section points.
- `leaflet_midrib_profile(; lamina_angle_deg, scale)`: open V-shaped leaflet section.

```@example procgeom
circle = circle_section_profile(14; radius=0.45, close_loop=true)
leaflet = leaflet_midrib_profile(; lamina_angle_deg=44.0, scale=0.45)

fig = Figure(size=(820, 320))
ax1 = Axis(fig[1, 1], title="circle_section_profile", aspect=DataAspect())
lines!(ax1, [p[1] for p in circle], [p[2] for p in circle], color=:steelblue, linewidth=3)
scatter!(ax1, [p[1] for p in circle], [p[2] for p in circle], color=:steelblue, markersize=7)

ax2 = Axis(fig[1, 2], title="leaflet_midrib_profile", aspect=DataAspect())
lines!(ax2, [p[1] for p in leaflet], [p[2] for p in leaflet], color=:forestgreen, linewidth=3)
scatter!(ax2, [p[1] for p in leaflet], [p[2] for p in leaflet], color=:forestgreen, markersize=9)

fig
```

### 2) Path interpolation helpers

- `extrusion_make_path(n, key_points; key_tangents=nothing)`: Hermite-style interpolation.
- `extrusion_make_spline(n, key_points)`: Catmull-Rom spline interpolation.

```@example procgeom
key_points = [
    Point(0.0, 0.0, 0.0),
    Point(0.2, 0.1, 0.04),
    Point(0.6, 0.14, 0.10),
    Point(1.0, 0.0, 0.16),
]

path_hermite = extrusion_make_path(70, key_points)
path_spline = extrusion_make_spline(70, key_points)

fig = Figure(size=(860, 420))
ax = Axis3(fig[1, 1], title="Path helper comparison")
lines!(
    ax,
    [p[1] for p in path_hermite],
    [p[2] for p in path_hermite],
    [p[3] for p in path_hermite],
    color=:dodgerblue,
    linewidth=3,
    label="extrusion_make_path",
)
lines!(
    ax,
    [p[1] for p in path_spline],
    [p[2] for p in path_spline],
    [p[3] for p in path_spline],
    color=:tomato,
    linewidth=3,
    label="extrusion_make_spline",
)
scatter!(
    ax,
    [p[1] for p in key_points],
    [p[2] for p in key_points],
    [p[3] for p in key_points],
    color=:black,
    markersize=12,
    label="key points",
)
axislegend(ax, position=:rb)
fig
```

### 3) Scalar interpolation helpers

- `extrusion_make_interpolation(n, key_values)`: linear interpolation of key scalar values.
- `extrusion_make_curve(z_keys, r_keys, n)`: AMAP-like extrema-preserving curve sampling.

```@example procgeom
key_values = [1.0, 0.92, 0.70, 0.42]
interp = extrusion_make_interpolation(60, key_values)
x_interp = range(0.0, 1.0; length=length(interp))

z_keys = [0.0, 0.22, 0.58, 1.0]
r_keys = [0.35, 0.24, 0.29, 0.10]
z_samples, r_samples = extrusion_make_curve(z_keys, r_keys, 120)

fig = Figure(size=(860, 360))
ax1 = Axis(fig[1, 1], title="extrusion_make_interpolation")
lines!(ax1, x_interp, interp, color=:purple4, linewidth=3)
scatter!(ax1, range(0.0, 1.0; length=length(key_values)), key_values, color=:black, markersize=8)

ax2 = Axis(fig[1, 2], title="extrusion_make_curve")
lines!(ax2, z_samples, r_samples, color=:darkorange3, linewidth=3)
scatter!(ax2, z_keys, r_keys, color=:black, markersize=8)

fig
```

### 4) Visual extrusion from profile + path

You can combine helper outputs directly with `extrude_profile_mesh`.

```@example procgeom
section = leaflet_midrib_profile(; lamina_angle_deg=40.0, scale=0.35)
path = extrusion_make_spline(70, key_points)
widths = extrusion_make_interpolation(70, [1.0, 0.95, 0.7, 0.45])
heights = extrusion_make_interpolation(70, [1.0, 1.0, 0.85, 0.60])

mesh_leaflet = extrude_profile_mesh(
    section,
    path;
    widths=widths,
    heights=heights,
    torsion=true,
    close_section=false,
    cap_ends=false,
)

fig = Figure(size=(860, 420))
ax = Axis3(fig[1, 1], title="extrude_profile_mesh (leaflet-like)")
mesh!(ax, mesh_leaflet, color=RGBA(0.18, 0.58, 0.28, 0.95))
lines!(
    ax,
    [p[1] for p in path],
    [p[2] for p in path],
    [p[3] for p in path],
    color=:black,
    linewidth=2,
)
fig
```

### 5) Lathe helpers

There are two ways to build lathe geometry:

- `lathe_mesh` / `lathe_refmesh`: start from sparse key profile data.
- `lathe_gen_mesh` / `lathe_gen_refmesh`: start from already sampled `(z, radius)` arrays.

`lathe_mesh(...; method=:curve)` uses `extrusion_make_curve` (extrema-preserving),
while `method=:spline` and `method=:path` use spline/Hermite interpolation.

```@example procgeom
z_keys_lathe = [0.0, 0.22, 0.58, 1.0]
r_keys_lathe = [0.34, 0.24, 0.28, 0.09]

lathe_curve = lathe_mesh(18, 90, z_keys_lathe, r_keys_lathe; method=:curve, axis=:x, cap_ends=true)
lathe_spline = lathe_mesh(18, 90, z_keys_lathe, r_keys_lathe; method=:spline, axis=:x, cap_ends=true)

fig = Figure(size=(980, 390))
ax1 = Axis3(fig[1, 1], title="lathe_mesh(method=:curve)")
mesh!(ax1, lathe_curve, color=RGBA(0.58, 0.44, 0.30, 0.95))

ax2 = Axis3(fig[1, 2], title="lathe_mesh(method=:spline)")
mesh!(ax2, lathe_spline, color=RGBA(0.30, 0.48, 0.70, 0.95))

fig
```

```@example procgeom
z_samples = collect(range(0.0, 1.0; length=80))
r_samples = [0.31 * (1 - z)^0.85 + 0.02 for z in z_samples]
lathe_gen = lathe_gen_mesh(18, z_samples, r_samples; axis=:x, cap_ends=true)

fig = Figure(size=(520, 380))
ax = Axis3(fig[1, 1], title="lathe_gen_mesh (pre-sampled profile)")
mesh!(ax, lathe_gen, color=RGBA(0.46, 0.36, 0.62, 0.95))
fig
```

## Recommended Pattern

- Repeated geometry: use cached procedural `RefMesh` constructors.
- Unique per-node geometry: use `ExtrudedTubeGeometry` directly on nodes.
- In both cases, render with the same `plantviz` pipeline.

See also:

- [`Reference Meshes`](refmesh.md)
- [`Building Plant Models`](building_plant_models.md)
- [`AMAPStudio Parity Matrix`](amap_parity_matrix.md)
