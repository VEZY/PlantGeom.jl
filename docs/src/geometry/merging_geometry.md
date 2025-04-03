# Merging Fine-Scale Geometry

```@setup merge_geometry
using PlantGeom, CairoMakie, Statistics
CairoMakie.activate!()
mtg = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf"))
```

## Overview

Plant architecture is often represented at multiple scales - from fine details like individual leaflets to coarser representations like whole leaves or branches. While detailed structural representation is valuable, there are significant computational benefits to merging fine-scale geometries into coarser scales:

- **Computational efficiency**: Processing a single merged mesh is faster than handling many small ones
- **Scale-appropriate analysis**: When analysis is performed at a coarser scale (e.g., axis level), there's no need to maintain separate geometries for each component
- **Streamlined visualization**: Rendering performance improves significantly with fewer meshes

PlantGeom provides tools to merge fine-scale geometries into coarser representations while preserving the complete geometric detail.

## The `merge_children_geometry!` Function

The `merge_children_geometry!` function allows you to merge geometries from lower-scale nodes into higher-scale parent nodes without losing geometric detail.

```julia
merge_children_geometry!(mtg; from, into, delete=:nodes, child_link_fun=new_child_link)
```

### Parameters

- `mtg`: The MultiScaleTreeGraph to process.
- `from`: The type(s) of nodes whose geometry should be merged upward (lower scale). Can be a string or a vector of strings, *e.g.* `["Metamer", "Leaf"]`.
- `into`: The type of nodes to merge into (higher scale). Must be a single string, *e.g.* "Axis".
- `delete`: A symbol indicating what to do after merging:
  - `:none`: Keep both the original nodes and their geometry.
  - `:geometry`: Keep the original nodes but remove their geometry (saves memory).
  - `:nodes`: Delete the original nodes entirely (requires a `child_link_fun`).
- `child_link_fun`: A function that handles reconnecting children when nodes are deleted.

## Example: Merging Coffee Plant Geometry

Let's walk through an example using a coffee plant model where we merge the geometry of metamers and leaves into their parent axis.

### Original Plant Model

First, let's look at the original coffee plant model with geometry at the metamer and leaf level:

```@example merge_geometry
using PlantGeom
using CairoMakie

# Load the coffee plant model
mtg = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf"))

# Visualize the original model
fig = Figure(size=(600, 600))
ax = Axis3(fig[1, 1], aspect=:data, title="Original Coffee Plant")
viz!(ax, mtg)
hidedecorations!(ax)
hidespines!(ax)
fig
```

In this visualization, each metamer and leaf has its own individual mesh. This results in thousands of small meshes that need to be processed and rendered separately.

### Merging Geometry while Keeping Nodes

We can merge the geometry from metamers and leaves up to the axis level while keeping the original node structure intact:

```@example merge_geometry
# Create a copy to preserve the original
mtg_merged1 = deepcopy(mtg)

# Merge geometry from "Metamer" and "Leaf" into "Axis"
merge_children_geometry!(mtg_merged1; 
    from=["Metamer", "Leaf"], 
    into="Axis", 
    delete=:geometry, 
)

# Visualize the result
fig = Figure(size=(600, 600))
ax = Axis3(fig[1, 1], aspect=:data, title="Merged Geometry (Keeping Nodes)")
viz!(ax, mtg_merged1)
hidedecorations!(ax)
hidespines!(ax)
fig
```

The plant looks identical, but the geometry is now stored at the axis level rather than at individual metamers and leaves. The original nodes still exist in the MTG structure, but their geometry properties have been removed to save memory.

### Merging Geometry and Deleting Nodes

For even more streamlined representation, we can completely remove the lower-scale nodes:

```@example merge_geometry
# Create a copy to preserve the original
mtg_merged2 = deepcopy(mtg)

# Merge geometry and delete the original nodes
merge_children_geometry!(mtg_merged2; 
    from=["Metamer", "Leaf"], 
    into="Axis", 
    delete=:nodes, 
)

# Visualize the result
fig = Figure(size=(600, 600))
ax = Axis3(fig[1, 1], aspect=:data, title="Merged Geometry (Nodes Deleted)")
viz!(ax, mtg_merged2)
hidedecorations!(ax)
hidespines!(ax)
fig
```

The visual result is still the same, but now the MTG structure has been simplified by removing the metamer and leaf nodes entirely. The complete geometry is preserved at the axis level.

### Performance Comparison

The performance improvements from merging geometry can be substantial:

```@example merge_geometry
using Statistics
# Run benchmarks (would be better to use BenchmarkTools, but this is an approximation)
original_time = @elapsed viz(mtg)
merged1_time = @elapsed viz(mtg_merged1)
merged2_time = @elapsed viz(mtg_merged2)

# Display the table
table_fig = Figure(size=(600, 200))
ax = Axis(table_fig[1, 1], title="Rendering Time (ms)", xticks = (1:3, ["Original Model", "Merged (Keeping Nodes)", "Merged (Nodes Deleted)"]))
barplot!(ax, 1:3, [original_time, merged1_time, merged2_time])
table_fig
```

## Use Cases

Geometry merging is particularly useful for:

1. **Light interception calculations** computed at the triangle level but integrated at axis scale
2. **Large-scale simulations** where computational efficiency is crucial
3. **Visualization of complex plants** where rendering performance matters
4. **Scale-appropriate modeling** where geometry is needed at higher scales but not at fine scales

## Notes

- Merging preserves all geometric detail but organizes it at a coarser scale
- The MTG structure can be maintained (using `delete=:geometry`) or simplified (using `delete=:nodes`)
- When deleting nodes, make sure to provide an appropriate `child_link_fun` to maintain connectivity. The default function `new_child_link` tries to be smart, but it may not suit your specific use case.
