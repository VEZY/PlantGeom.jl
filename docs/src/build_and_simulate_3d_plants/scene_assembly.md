+++
title = "Assemble a Mixed Scene"
+++

# Assemble a Mixed Scene

This page shows the recommended way to build a proper scene MTG from a mix of:

- plants imported from files (`.opf` or `.gwa`)
- plants generated in Julia with the growth API

The key rule is:

- keep each object in its own local coordinates
- place it in the scene with [`place_in_scene!`](@ref)

That helper stores the OPS placement metadata on the object root and, by default,
also applies the corresponding transform to the geometry in memory. This keeps
`plantviz(scene)` and `write_ops(scene, ...)` consistent.

## Important constraint: use the same MTG type for all scene children

Manual scene assembly attaches multiple independent MTG roots under one `:Scene`
root. Those roots must use the same MTG encoding type.

Today, the simplest mixed-scene workflow is:

- create the scene root with `NodeMTG`
- read imported OPF/GWA objects with `mtg_type=NodeMTG`
- build generated plants with the growth API (which already uses `NodeMTG`)

If you mix `NodeMTG` and `MutableNodeMTG` roots in the same manual scene,
`addchild!` will fail.

## Example

```@example mixedscene
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics
using CairoMakie

include(joinpath(pkgdir(PlantGeom), "docs", "src", "getting_started", "tree_demo_helpers.jl"))

files_dir = joinpath(pkgdir(PlantGeom), "test", "files")

scene = Node(NodeMTG(:/, :Scene, 1, 0))
scene.scene_dimensions = (
    Point{3,Float64}(0.0, 0.0, 0.0),
    Point{3,Float64}(8.0, 4.0, 0.0),
)

imported = read_opf(joinpath(files_dir, "simple_plant.opf"); mtg_type=NodeMTG)
generated = build_demo_tree_with_growth_api()

place_in_scene!(
    imported;
    scene=scene,
    scene_id=1,
    plant_id=1,
    functional_group="imported",
    pos=(1.0, 1.0, 0.0),
    rotation=0.25,
)

place_in_scene!(
    generated;
    scene=scene,
    scene_id=1,
    plant_id=2,
    functional_group="generated",
    pos=(4.7, 1.4, 0.0),
    scale=1.15,
    rotation=-0.35,
    inclination_angle=0.12,
)

f, ax, p = plantviz(scene, figure=(size=(920, 620),))
f
```

## What `place_in_scene!` does

For each object root, it writes scene metadata attributes compatible with OPS:

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

That last point matters when you manually assemble a scene from several roots:
two separate plants often both start at node id `1`.

## Reusing the same object more than once

If you want several copies of the same imported or generated object, duplicate
the object root before placing it:

```julia
base_plant = read_opf("myplant.opf"; mtg_type=NodeMTG)

copy_1 = deepcopy(base_plant)
copy_2 = deepcopy(base_plant)

place_in_scene!(copy_1; scene=scene, plant_id=1, pos=(0.0, 0.0, 0.0))
place_in_scene!(copy_2; scene=scene, plant_id=2, pos=(2.0, 0.0, 0.0))
```

Do not attach the exact same node object twice.

## Export to OPS

Once the scene is assembled, export it with:

```julia
write_ops("mixed_scene.ops", scene)
```

This will:

- write the OPS scene table
- emit one object file per child of the scene root
- undo each child's `scene_transformation` before writing the object file
- preserve the final placed geometry when you read the OPS back with [`read_ops`](@ref)

## Imported files other than OPF

The same pattern works for imported `.gwa` objects too:

```julia
obj = read_gwa("object.gwa"; mtg_type=NodeMTG)
place_in_scene!(obj; scene=scene, plant_id=3, pos=(6.0, 1.0, 0.0))
```

## When not to use `place_in_scene!`

If you only want a single standalone plant/object, keep it as an object-local
MTG and write it directly with [`write_opf`](@ref) or [`write_gwa`](@ref).

Use `place_in_scene!` only when the object is meant to live inside a scene.
