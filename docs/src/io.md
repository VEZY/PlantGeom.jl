# IO and File Formats

!!! info "Page Info"
    - **Audience:** Beginner to Intermediate
    - **Prerequisites:** basic PlantGeom usage
    - **Time:** 10 minutes
    - **Output:** Correct choice and usage of OPF/OPS/MTG readers and writers

PlantGeom works with four complementary representations:

- `MTG` on disk and in memory: the graph structure written in `.mtg` files that you can import and manipulate in Julia using [MultiScaleTreeGraph.jl](https://github.com/VEZY/MultiScaleTreeGraph.jl).
- `OPF` on disk: one plant object with topology + geometry stored in the OPF format (`.opf`). This is basically an `.mtg` file with geometry data.
- `GWA` on disk: a 3D object with geometry but not topology stored in the GWA format (`.gwa`).
- `OPS` on disk: a scene file that places multiple plant objects (i.e. OPF/GWA objects) in space. It is stored in the OPS format (`.ops`).

## Mental Model

- Use `read_opf` when you want one plant object with its geometry.
- Use `read_gwa` when you want one standalone 3D object without topology (e.g. a solar panel, or a single leaf).
- Use `read_ops` when you want a whole scene (many OPF/GWA objects + scene transforms).
- Use `read_mtg` when you have topology/attributes only (no explicit mesh geometry).

In all cases, PlantGeom builds a `MultiScaleTreeGraph` in memory.

## What Is Inside an OPF?

An OPF (`.opf`) is an XML file describing one object (typically one plant):

- mesh definitions (`meshBDD`)
- materials (`materialBDD`)
- mesh/material mapping (`shapeBDD`)
- attribute dictionary (`attributeBDD`)
- MTG topology and per-node values (`topology`), which is the graph structure with node attributes (*i.e.* the mtg), including geometry (transformation matrix and reference-mesh `shapeIndex`).

Minimal structure (illustrative):

```xml
<opf version="2.0" editable="true">
  <meshBDD>...</meshBDD>
  <materialBDD>...</materialBDD>
  <shapeBDD>...</shapeBDD>
  <attributeBDD>...</attributeBDD>
  <topology>...</topology>
</opf>
```

## What Is Inside an OPS?

An OPS (`.ops`) is a scene file, not a mesh file. It stores:

- scene dimensions (`T ... flat` line)
- a list of object rows (path to `.opf`/`.gwa` + transform values)
- optional functional-group sections (`#[Archimed] ...`)

Each object row references a plant file and gives scene placement:

- position (`x y z`)
- scale
- inclination azimuth + angle
- rotation

So: `OPS` = *where objects are in the scene*, `OPF` = *what each object is*.

## What Is an MTG File?

An MTG file (`.mtg`) stores graph topology and attributes in text form.
It is very convenient for reconstruction workflows because it is lightweight and
human-readable, but it does not carry explicit mesh geometry.

These files typically come from field measurements. You can still perform semi-automatic reconstruction if it has standard attributes with `set_geometry_from_attributes!` or `reconstruct_geometry_from_attributes!`.

## Reading Reference Meshes from `.ply` / `.obj`

PlantGeom does not provide dedicated `read_ply`/`read_obj` functions, because they are defined in external packages like `FileIO` and `MeshIO`.

The usual approach is:

1. load external mesh files with `FileIO` + `MeshIO`
2. convert to a `GeometryBasics` mesh (if needed)
3. wrap into `RefMesh`

```julia
using PlantGeom
using GeometryBasics
using Colors
using FileIO
using MeshIO

# Load a polygon mesh from disk (.ply, .obj, ...)
raw_mesh = load("leaf.ply")

# Convert to GeometryBasics mesh when required by the loader output:
mesh_gb = GeometryBasics.mesh(raw_mesh)

# Wrap it as a PlantGeom reference mesh:
leaf_ref = RefMesh("LeafFromPLY", mesh_gb, RGB(0.18, 0.58, 0.28))
```

Same idea for OBJ:

```julia
stem_ref = RefMesh("StemFromOBJ", GeometryBasics.mesh(load("stem.obj")), RGB(0.55, 0.42, 0.30))
```

You can then use these `RefMesh` objects directly in `Geometry(...)`,
`set_geometry_from_attributes!`, or reconstruction dictionaries.

For the procedural counterpart (direct node geometries with `ExtrudedTubeGeometry`
and extrusion helpers), see:
[`Procedural / Extrusion Geometry`](geometry/procedural_geometry.md).

## Reading Examples

```@example io
using PlantGeom
using MultiScaleTreeGraph

files_dir = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files")
opf_file = joinpath(files_dir, "simple_plant.opf")
ops_file = joinpath(files_dir, "scene.ops")
mtg_file = joinpath(files_dir, "reconstruction_standard.mtg")

opf = read_opf(opf_file)
scene_dimensions, object_table = read_ops_file(ops_file)
scene = read_ops(ops_file)
mtg_topology = read_mtg(mtg_file)

(
    opf_nodes_with_geometry=length(descendants(opf, :geometry; ignore_nothing=true, self=true)),
    scene_objects=length(object_table),
    scene_children=length(children(scene)),
    mtg_nodes=length(descendants(mtg_topology; self=true)),
)
```

## Writing Examples

```@example io
tmp_opf = tempname() * ".opf"
tmp_ops = tempname() * ".ops"
tmp_ops_rows = tempname() * ".ops"

write_opf(tmp_opf, opf)
write_ops(tmp_ops, scene) # default: writes OPS + emitted OPF/GWA object files
write_ops_file(tmp_ops_rows, scene_dimensions, object_table) # rows only

opf_roundtrip = read_opf(tmp_opf)
ops_roundtrip = read_ops_file(tmp_ops)
ops_rows_roundtrip = read_ops_file(tmp_ops_rows)

summary = (
    opf_written=isfile(tmp_opf),
    ops_written=isfile(tmp_ops),
    ops_rows_written=isfile(tmp_ops_rows),
    opf_roundtrip_nodes=length(descendants(opf_roundtrip, :geometry; ignore_nothing=true, self=true)),
    ops_roundtrip_rows=length(ops_roundtrip.object_table),
    ops_rows_roundtrip_rows=length(ops_rows_roundtrip.object_table),
)

rm(tmp_opf; force=true)
rm(tmp_ops; force=true)
rm(tmp_ops_rows; force=true)

summary
```

## Writing A Scene Properly

There are two supported ways to write an OPS scene:

- `write_ops_file(file, scene_dimensions, object_table)` if you already have a
  table of scene rows
- `write_ops(file, scene)` if you already assembled a scene MTG in memory

### Required scene contract for `write_ops(file, scene)`

For `write_ops(file, scene)`, PlantGeom expects:

- a scene root whose children are object roots
- optional `scene.scene_dimensions` stored as
  `(Point3(xmin, ymin, z), Point3(xmax, ymax, z))`
- optional placement metadata on each child object root:
  `sceneID`, `plantID`, `functional_group`, `pos`, `scale`,
  `inclinationAzimut`, `inclinationAngle`, `rotation`, `filePath`

Defaults are used when these attributes are missing, but if you want a scene
that is both:

- correct in memory for `plantviz(scene)`
- and correct when exported with `write_ops(scene)`

then the recommended workflow is to place each object with
[`place_in_scene!`](build_and_simulate_3d_plants/scene_assembly.md).

### Required row contract for `write_ops_file(file, scene_dimensions, object_table)`

For `write_ops_file`, each row in `object_table` can provide:

- `sceneID`
- `plantID`
- `filePath`
- `pos`
- `scale`
- `inclinationAzimut`
- `inclinationAngle`
- `rotation`
- `functional_group`

All are optional and default to the same values used by `write_ops`.

For a complete scene-building workflow mixing generated plants and imported
objects, see:
[Assemble a Mixed Scene](build_and_simulate_3d_plants/scene_assembly.md).

## OPF Reference Mesh IDs

`read_opf` stores reference meshes on the MTG root as `opf[:ref_meshes]`, a
`Dict{Int,RefMesh}` keyed by OPF shape IDs (the same IDs used by
`shapeIndex`, typically 0-based).

```@example io
ref_meshes_by_id = opf[:ref_meshes]
shape_ids = sort(collect(keys(ref_meshes_by_id)))
(
    n_ref_meshes=length(ref_meshes_by_id),
    first_shape_id=first(shape_ids),
    id_type=eltype(shape_ids),
)
```

If you only need a list for plotting, use `get_ref_meshes(opf)` (or
`collect(values(opf[:ref_meshes]))`).

## Which Reader Should I Use?

| Goal | Recommended function |
| --- | --- |
| Load one plant object with explicit geometry | `read_opf(file)` |
| Parse an OPS scene table without loading all geometry | `read_ops_file(file)` |
| Load the full OPS scene as MTG children + transforms | `read_ops(file)` |
| Load topology/attributes text for reconstruction | `read_mtg(file)` |

## Practical Notes

- `read_ops` resolves object file paths relative to the OPS file directory.
- `write_ops(file, scene)` writes the OPS scene table and, by default, emits one
  OPF/GWA object file per scene child.
- `write_ops_file(file, scene_dimensions, object_table)` writes only the OPS
  scene table rows (no object files emitted).
- You can override OPF attribute typing explicitly with
  `read_opf(file; attribute_types=Dict("Length" => Float64))` (same keyword is
  available in `read_ops` and forwarded to embedded OPFs).
- For reconstruction workflows from `.mtg`, see:
  [AMAP-Style Quickstart](build_and_simulate_3d_plants/reconstruct_from_mtg/amap_quickstart.md).
