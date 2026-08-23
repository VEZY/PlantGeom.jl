# Assemble a Scene

This page shows the recommended way to build a scene from:

- plants imported from files (`.opf` or `.gwa`)
- plants generated in Julia with the growth API
- optional ground geometry

TLDR: Use the [`make_scene`](@ref) function. It creates the scene root, places objects, relabels node ids, and returns a prepared
[`SceneGeometry`](@ref).

## Recommended API

```@example mixedscene
using PlantGeom
using MultiScaleTreeGraph
using CairoMakie

include(joinpath(pkgdir(PlantGeom), "docs", "src", "getting_started", "tree_demo_helpers.jl"))

files_dir = joinpath(pkgdir(PlantGeom), "test", "files")

imported = read_opf(joinpath(files_dir, "simple_plant.opf"); mtg_type=NodeMTG)
generated = build_demo_tree_with_growth_api()

scene = make_scene(domain=(0.0, 0.0, 8.0, 4.0)) do sc
    add_plant!(
        sc,
        imported;
        group="imported",
        id=1,
        at=(1.0, 1.0, 0.0),
        rotation=0.25,
    )

    add_plant!(
        sc,
        generated;
        group="generated",
        id=2,
        at=(4.7, 1.4, 0.0),
        scale=1.15,
        rotation=-0.35,
        inclination_angle=0.12,
    )

    add_ground!(sc; nx=8, ny=4, group="ground", type="Ground")
end

f, ax, p = plantviz(scene.mtg, figure=(size=(920, 620),))
f
```

The `domain` is `(xmin, ymin, xmax, ymax)` in scene coordinates. It is also used
as the default ground extent when you call [`add_ground!`](@ref) inside the
builder block.

## Add Objects

Use [`add_plant!`](@ref) for plant-like MTGs and [`add_object!`](@ref) for
standalone objects (like solar panels, or buildings).

```julia
oak = read_opf("plants/oak.opf"; mtg_type=NodeMTG)
bench = read_gwa("objects/bench.gwa"; mtg_type=NodeMTG)

scene = make_scene(domain=(0.0, 0.0, 10.0, 6.0)) do sc
    add_plant!(
        sc,
        oak;
        group="trees",
        id=1,
        at=(2.0, 2.0, 0.0),
        rotate=(z=20.0,),
        deg=true,
    )

    add_object!(
        sc,
        bench;
        group="furniture",
        id=10,
        type="Bench",
        at=(6.0, 1.5, 0.0),
        scale=0.8,
    )
end
```

In mixed scenes, use the same MTG encoding type for the scene root and imported objects.
By default, [`make_scene`](@ref) creates a `NodeMTG` scene root. If your objects
use `MutableNodeMTG`, pass the same type to `make_scene`:

```julia
oak = read_opf("plants/oak.opf"; mtg_type=MutableNodeMTG)

scene = make_scene(domain=(0.0, 0.0, 10.0, 6.0); mtg_type=MutableNodeMTG) do sc
    add_plant!(sc, oak; group="trees", id=1)
end
```

Placement (*e.g.* `add_plant!`) can use the simple transform API:

- `at=(x, y, z)`
- `scale=s` or `scale=(sx, sy, sz)`
- `rotate=(x=..., y=..., z=...)`
- `deg=true` when rotation angles are in degrees

It can also use OPS-style placement:

- `rotation=...`
- `inclination_azimut=...`
- `inclination_angle=...`

Do not mix `rotate=` with OPS-style `rotation=` / `inclination_*=` placement in
the same object call.

## Reusing the Same Object More Than Once

`add_plant!` and `add_object!` copy MTG inputs before attaching them, so the same
loaded object can be reused safely:

```julia
base_plant = read_opf("myplant.opf"; mtg_type=NodeMTG)

scene = make_scene(domain=(0.0, 0.0, 5.0, 3.0)) do sc
    add_plant!(sc, base_plant; group="plants", id=1, at=(0.0, 0.0, 0.0))
    add_plant!(sc, base_plant; group="plants", id=2, at=(2.0, 0.0, 0.0))
end
```

Each insertion receives its own source-instance namespace. Consequently, two
copies may keep the same object-local node ids without colliding in downstream
models.

## Trace Geometry Back to Botanical Organs

A scene contains several distinct kinds of identity:

- a scene MTG node id identifies the copied and possibly relabelled scene node;
- `source_topology_id` is optional provenance copied from the input topology;
- [`SourceOwnerKey`](@ref) identifies the botanical source object that owns a
  geometric component.

Use [`source_owner`](@ref) or [`source_owners`](@ref) when results calculated on
scene components must be assigned back to botanical organs:

```julia
for scene_node_id in scene_node_ids(scene)
    owner = source_owner(scene, scene_node_id)
    # Compile `owner` to the corresponding object in the downstream model.
end
```

The complete `SourceOwnerKey` is the identity. Its `source_instance_id`
distinguishes repeated insertions and independent input topologies, while its
`source_node_id` identifies the owner inside that source object. The key is
scene-local: do not persist either integer alone as a globally stable botanical
identifier, and do not infer ownership from mesh-face order.

By default, every geometry-bearing node owns its own component. Compound
organs can provide a resolver when they are inserted. For example, leaflet
meshes can be owned by their enclosing `Leaf`:

```julia
function nearest_leaf(node)
    current = node
    while MultiScaleTreeGraph.symbol(current) !== :Leaf
        MultiScaleTreeGraph.isroot(current) &&
            error("No Leaf ancestor found for scene geometry")
        current = MultiScaleTreeGraph.parent(current)
    end
    return current
end

scene = make_scene(domain=(0.0, 0.0, 5.0, 3.0)) do sc
    add_plant!(
        sc,
        compound_plant;
        group="plants",
        id=1,
        source_owner=nearest_leaf,
    )
end
```

Several scene nodes may then share one owner key. The mapping survives copying,
placement transforms, scene-node relabelling, and later scene preparation.
Calling `add_plant!` or `add_object!` again preserves an existing botanical
mapping by default while assigning the copy a fresh source-instance namespace;
passing a new `source_owner` resolver recomputes it explicitly.

`prepare_scene` records private `_scene_*` attributes on the scene MTG to retain
this information across refreshes and organogenesis. PlantGeom's OPF writer
omits these implementation attributes. Moving an already stamped node between
two source instances is deliberately rejected: such a move would change the
meaning of its owner key. Reassemble or reinsert the complete object when a new
source-instance identity is intended; reparenting within the same source
instance remains supported.

## Export to OPS

`make_scene` returns a [`SceneGeometry`](@ref). The MTG scene root is stored in
`scene.mtg`:

```julia
write_ops("mixed_scene.ops", scene.mtg)
```

This will:

- write the OPS scene table
- emit one object file per child of the scene root
- preserve the final placed geometry when you read the OPS back with [`read_ops`](@ref)

## Inspect Prepared Scene Geometry

The returned [`SceneGeometry`](@ref) also contains a merged mesh and per-node
geometry summaries:

```julia
scene.merged_mesh
scene_node_ids(scene)
node_areas(scene)
node_barycenters(scene)
```

This representation is useful when a downstream model needs one mesh plus a map
from faces back to MTG node ids.

## Advanced: Manual Scene Roots

A lower-level API is also available when you need explicit control over the
scene root or want to work directly with OPS placement metadata. In that case,
create a `:Scene` root yourself and attach objects with [`place_in_scene!`](@ref).

```julia
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics

scene = Node(NodeMTG(:/, :Scene, 1, 0))
scene.scene_dimensions = (
    Point{3,Float64}(0.0, 0.0, 0.0),
    Point{3,Float64}(8.0, 4.0, 0.0),
)

imported = read_opf("simple_plant.opf"; mtg_type=NodeMTG)

place_in_scene!(
    imported;
    scene=scene,
    scene_id=1,
    plant_id=1,
    functional_group="imported",
    at=(1.0, 1.0, 0.0),
    rotation=0.25,
)
```

For each object root, [`place_in_scene!`](@ref) writes scene metadata compatible
with OPS:

- `sceneID`
- `plantID`
- `functional_group`
- `pos`
- `scale`
- `rotation`
- `inclinationAzimut`
- `inclinationAngle`
- optionally `filePath`

And by default it also:

- computes the same placement transform used by [`read_ops`](@ref)
- applies it to all geometry nodes in the object subtree
- stores that transform as `scene_transformation`
- relabels node ids when attaching the object to a scene so independent trees do not collide

Two separate objects often both start at node id `1`, so relabeling matters when
you attach multiple roots under one scene.

## MTG Type Constraint

Scene assembly attaches multiple independent MTG roots under one `:Scene` root.
Those roots must use the same MTG encoding type.

The simplest mixed-scene workflow is:

- create or let `make_scene` create a `NodeMTG` scene root
- read imported OPF/GWA objects with `mtg_type=NodeMTG`
- build generated plants with the growth API, which already uses `NodeMTG`

If your input objects use `MutableNodeMTG`, call
`make_scene(...; mtg_type=MutableNodeMTG)` and load all imported objects with
`mtg_type=MutableNodeMTG`.

If you mix `NodeMTG` and `MutableNodeMTG` roots in the same manual scene,
`addchild!` will fail.

## When Not To Build A Scene

If you only want a single standalone plant/object, keep it as an object-local
MTG and write it directly with [`write_opf`](@ref) or [`write_gwa`](@ref).

Build a scene only when the object is meant to live inside a larger spatial
assembly.
