# Building Plant Models

```@setup buildgeom
using PlantGeom, MultiScaleTreeGraph
using WGLMakie, Colors
import TransformsBase: → # The → operator from TransformsBase composes transformations
using Meshes, Rotations
using Bonito
Page()
WGLMakie.activate!()

# Build reference meshes:
cylinder = Meshes.CylinderSurface(Meshes.Point(0.0, 0.0, 0.0), Meshes.Point(0.0, 0.0, 1.0), 0.5) |> 
           Meshes.discretize |> Meshes.simplexify
refmesh_cylinder = RefMesh("Cylinder", cylinder, RGB(0.5, 0.5, 0.5))
# RGB(0, 0.5, 0), RGB(0, 0.5, 0.1), RGB(0.1, 0.5, 0)]
# Make a reference mesh for the leaves:
w = l = 1 # Leaf width and length are set to 1.0 to facilitate transformations
p = 0.2 * l # Petiole length is set to 20% of the leaf length
points = [
        (0.0, -0.05 * w, 0.0), # Petiole base 1
        (0.0, 0.05 * w, 0.0), # Base 2. NB: the petiole base width is 5% of the leaf width 
        (p, 0.0, 0.0), # End of petiole, first point of leaf blade
        (p + l, 0.0, 0.0), # tip of the leaf
        (p + l / 2.0, -w / 2.0, 0.0),
        (p + l / 2.0, w / 2.0, 0.0)
    ]

connec = Meshes.connect.(
    [
        (1, 2, 3), # Petiole
        (3, 5, 4), # left part of the leaf
        (3, 6, 4)  # right part of the leaf
    ],
    Triangle
)

refmesh_leaf = RefMesh("Leaf", Meshes.SimpleMesh(points, connec), RGB(0.1, 0.5, 0))

function build_mtg(n_internode=5, n_roots = 3)
    # Starting with the plant scale:
    mtg = Node(NodeMTG("/", "Plant", 1, 1))

    # Then, adding internodes and leaves recursively:
    last_node = mtg
    for i in 1:n_internode
        internode = Node(last_node, NodeMTG(i == 1 ? "/" : "<", "Internode", i, 2))
        Node(internode, NodeMTG("+", "Leaf", i, 2)) # Branching with a leaf
        last_node = internode
    end

    # And finally, adding the roots:
    last_root = mtg
    for i in 1:n_roots
        last_root = Node(last_root, NodeMTG(i == 1 ? "/" : "<", "RootSegment", i, 2))
    end

    return mtg
end

function add_geometry!(mtg, refmesh_cylinder, refmesh_leaf)
    # Track the current height for positioning internodes
    current_height = 0.0
    internode_width = 0.1
    internode_length = 0.3
    root_width = 0.05
    root_length = 0.5
    root_depth = -0.5  # Start below ground
    phyllotaxy = 0.0

    traverse!(mtg) do node
        if symbol(node) == "Internode"
            # Scale and position the internode
            transformation = Meshes.Scale(internode_width, internode_width, internode_length) → 
            Meshes.Translate(0.0, 0.0, current_height)
            
            # Attach geometry to this node
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_cylinder, transformation=transformation)
            
            # Update the height for the next internode
            current_height += internode_length
            phyllotaxy += π/2

        elseif symbol(node) == "Leaf"
            # Scale, rotate, and position the leaf
            leaf_length = 0.20 + 0.10*current_height
            leaf_width = 0.5 * leaf_length
            transformation = Meshes.Scale(leaf_length, leaf_width, 1e-6) → 
                             Meshes.Rotate(RotY(-π/4)) → # Give an insertion angle to the leaf
                             Meshes.Translate(internode_width/2.0, 0.0, current_height) → # Position on the stem
                             Meshes.Rotate(RotZ(phyllotaxy))                            
            # Attach geometry to this node
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_leaf, transformation=transformation)
        elseif symbol(node) == "RootSegment"
            # Scale and position the root (going downward)            
            transformation = Meshes.Scale(root_width, root_width, root_length) →
                             Meshes.Translate(0.0, 0.0, root_depth) →
                             Meshes.Rotate(RotZ(π))  # Point downward
            
            # Attach geometry to this node
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_cylinder,
                                              transformation=transformation)
            
            # Update the depth for the next root segment
            root_depth -= root_length
        end
    end
end

mtg = build_mtg()
add_geometry!(mtg, refmesh_cylinder, refmesh_leaf)

```

## Overview

This guide explains how to build complete plant geometries by combining reference meshes with transformations and associating them with nodes in a MultiScaleTreeGraph (MTG) structure. PlantGeom makes it easy to create realistic 3D plant models by leveraging reference meshes for different organ types and applying appropriate transformations.

## Geometry in MTG Nodes

In PlantGeom, 3D geometries are attached to MTG nodes through the `:geometry` attribute. Each node's geometry is represented by a `Geometry` object, which typically contains:

1. A reference to a `RefMesh` that defines the base shape
2. A transformation that positions, scales, and orients the mesh

```julia
# The core Geometry type
PlantGeom.Geometry(; 
    ref_mesh::RefMesh,                  # The reference mesh to use
    transformation=Identity(),          # Transformation to apply to the reference mesh (here, no transformation)
)
```

`Geometry` also has the `dUp` and `dDwn` arguments for appyling tapering to the geometry (*i.e.* make it pointy), but it is rarely used in practice, and is there for backward compatibility with the OPF file format. It also has the `mesh` field, which is used to store the mesh resulting from applying the transformation to the reference mesh. This one is lazily computed because we prefer not store it unless we really have to.

## Creating Plant Organ Geometries

The typical workflow for building a plant geometry is:

1. Create reference meshes for each organ type (*e.g.*, stem, leaf, root)
2. Traverse the MTG structure
3. For each node, create a Geometry with the appropriate reference mesh and transformation

### Step 1: Create Reference Meshes

First, define a reference mesh for each type of plant organ:

```@example buildgeom
using PlantGeom
using Meshes, Colors

# Create a cylinder reference mesh for internodes and roots, oriented towards the z direction
cylinder = Meshes.CylinderSurface(Meshes.Point(0.0, 0.0, 0.0), Meshes.Point(0.0, 0.0, 1.0), 0.5) |> 
           Meshes.discretize |> Meshes.simplexify
refmesh_cylinder = RefMesh("Cylinder", cylinder, RGB(0.5, 0.5, 0.5))
# RGB(0, 0.5, 0), RGB(0, 0.5, 0.1), RGB(0.1, 0.5, 0)]
# Make a reference mesh for the leaves:
w = l = 1 # Leaf width and length are set to 1.0 to facilitate transformations
p = 0.2 * l # Petiole length is set to 20% of the leaf length
points = [
        (0.0, -0.05 * w, 0.0), # Petiole base 1
        (0.0, 0.05 * w, 0.0), # Base 2. NB: the petiole base width is 5% of the leaf width 
        (p, 0.0, 0.0), # End of petiole, first point of leaf blade
        (p + l, 0.0, 0.0), # tip of the leaf
        (p + l / 2.0, -w / 2.0, 0.0),
        (p + l / 2.0, w / 2.0, 0.0)
    ]

connec = Meshes.connect.(
    [
        (1, 2, 3), # Petiole
        (3, 5, 4), # left part of the leaf
        (3, 6, 4)  # right part of the leaf
    ],
    Triangle
)

refmesh_leaf = RefMesh("Leaf", Meshes.SimpleMesh(points, connec), RGB(0.1, 0.5, 0))
```

### Step 2: Make a plant graph

For this example, we'll create a very simple plant that has only one meristem going upward, producing one internode and one leaf per internode, and one root meristem going downward.

```@example buildgeom
using MultiScaleTreeGraph

function build_mtg(n_internode=5, n_roots = 3)
    # Starting with the plant scale:
    mtg = Node(NodeMTG("/", "Plant", 1, 1))

    # Then, adding internodes and leaves recursively:
    last_node = mtg
    for i in 1:n_internode
        internode = Node(last_node, NodeMTG(i == 1 ? "/" : "<", "Internode", i, 2))
        Node(internode, NodeMTG("+", "Leaf", i, 2)) # Branching with a leaf
        last_node = internode
    end

    # And finally, adding the roots:
    last_root = mtg
    for i in 1:n_roots
        last_root = Node(last_root, NodeMTG(i == 1 ? "/" : "<", "RootSegment", i, 2))
    end

    return mtg
end

# Now let's use our function to create a plant:

mtg = build_mtg()
```

### Step 3: Associate Geometries with MTG Nodes

Next, traverse the MTG and assign the appropriate geometry to each node:

```@example buildgeom
using MultiScaleTreeGraph
import TransformsBase: → # The → operator from TransformsBase composes transformations
using Rotations

function add_geometry!(mtg, refmesh_cylinder, refmesh_leaf)
    # Track the current height for positioning internodes
    current_height = 0.0
    internode_width = 0.1
    internode_length = 0.3
    root_width = 0.05
    root_length = 0.5
    root_depth = -0.5  # Start below ground
    phyllotaxy = 0.0

    traverse!(mtg) do node
        if symbol(node) == "Internode"
            # Scale and position the internode
            transformation = Meshes.Scale(internode_width, internode_width, internode_length) → 
            Meshes.Translate(0.0, 0.0, current_height)
            
            # Attach geometry to this node
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_cylinder, transformation=transformation)
            
            # Update the height for the next internode
            current_height += internode_length
            phyllotaxy += π/2

        elseif symbol(node) == "Leaf"
            # Scale, rotate, and position the leaf
            leaf_length = 0.20 + 0.10*current_height
            leaf_width = 0.5 * leaf_length
            transformation = Meshes.Scale(leaf_length, leaf_width, 1e-6) → 
                             Meshes.Rotate(RotY(-π/4)) → # Give an insertion angle to the leaf
                             Meshes.Translate(internode_width/2.0, 0.0, current_height) → # Position on the stem
                             Meshes.Rotate(RotZ(phyllotaxy))                            
            # Attach geometry to this node
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_leaf, transformation=transformation)
        elseif symbol(node) == "RootSegment"
            # Scale and position the root (going downward)            
            transformation = Meshes.Scale(root_width, root_width, root_length) →
                             Meshes.Translate(0.0, 0.0, root_depth) →
                             Meshes.Rotate(RotZ(π))  # Point downward
            
            # Attach geometry to this node
            node.geometry = PlantGeom.Geometry(ref_mesh=refmesh_cylinder,
                                              transformation=transformation)
            
            # Update the depth for the next root segment
            root_depth -= root_length
        end
    end
end
```

### Step 4: Visualize the Plant

We can build a plant and compute the geometry of each node using the previous two functions:

```@example buildgeom
mtg = build_mtg()
add_geometry!(mtg, refmesh_cylinder, refmesh_leaf)
```

And finally, we can visualize our plant:

```@example buildgeom
using PlantGeom, WGLMakie  # or GLMakie for interactive 3D, or CairoMakie for printing quality

# Visualize the plant
fig = Figure()
ax = Axis3(fig[1, 1], aspect=:data)
viz!(ax, mtg)
fig
```

## Working with Direct Meshes

In some cases, you may want to use the transformed mesh directly rather than reference meshes. This is particularly useful for complex or unique organ shapes such as grass leaves. In this case, you can provide the mesh as a reference mesh:

```julia
# Direct mesh approach
complex_leaf_mesh = load_mesh("complex_leaf.obj")

# During MTG traversal:
node.geometry = PlantGeom.Geometry(ref_mesh=complex_leaf_mesh)
```

By default, `Geometry` uses the `Identity` transformation, which means no transformation.

## Tips for Building Realistic Plant Geometries

1. **Understand mesh orientation**: Know the default orientation of your reference meshes to apply transformations correctly
2. **Use transformation composition**: The `→` operator allows clean composition of multiple transformations
3. **Scale appropriately**: Make sure organ scales match realistically with each other
4. **Phyllotaxy patterns**: Implement botanical phyllotaxy patterns (opposite, alternate, whorled, etc.)
5. **Calibrate transformations**: You may need to experiment with transformation parameters to get realistic positioning

## Conclusion

By combining reference meshes with appropriate transformations, you can build complex and realistic 3D plant models efficiently. The use of reference meshes saves memory and computational resources while still allowing for detailed and visually appealing plant representations.

## More examples

You can look at [VPalm.jl](https://github.com/PalmStudio/VPalm.jl) to get an idea of a more complex 3D reconstruction of a plant using sequential architectural allometries.
