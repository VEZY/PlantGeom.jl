#! Transformations of the meshes. Uses:
#! Meshes.jl for scaling and translation
#! Meshes.jl + Rotations.jl for rotations
#! `TransformsBase.Identity`
#! Or a wrapper around CoordinateTransformations.jl for translation and scaling (see https://github.com/VEZY/PlantGeom.jl/issues/53)
# Voir https://stackoverflow.com/questions/10546320/remove-rotation-from-a-4x4-homogeneous-transformation-matrix
# pour extraire la rotation et la translation depuis la matrice 4*4, puis transformer
# cette matrice 4*4 en Meshes.jl transformations et après on ne gèrera que ces transformations là.

"""
    transform_mesh!(node::Node, transformation)

Add a new transformation to the node geometry `transformation` field. 
The transformation is composed with the previous transformation if any.

`transformation` must be a function.

It is also possible to invert a transformation using `revert` from `Meshes.jl`.

# Examples

```julia
using PlantGeom, MultiScaleTreeGraph, GLMakie, Rotations, Meshes

file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
opf = read_opf(file)

# Visualize the mesh as is:
viz(opf)

# Copy the OPF, and translate the whole plant by 15 in the y direction (this is in cm, the mesh comes from XPlo):
opf2 = deepcopy(opf)
transform!(opf2, x -> transform_mesh!(x, Translate(0, 15, 0)))
viz!(opf2) # Visualize it again in the same figure

# Same but rotate the whole plant around the X axis:
opf3 = deepcopy(opf)
transform!(opf3, x -> transform_mesh!(x, Rotate(RotX(0.3))))
# NB: we use Rotations.jl's RotX here. Input in radian, use rad2deg and deg2rad if needed.
viz!(opf3)

# Same but rotate only the second leaf around the Z axis:
opf4 = deepcopy(opf)
# Build the meshes from the reference meshes (need it because we want the coordinates of the parent):
transform!(opf4, refmesh_to_mesh!)

# Get the second leaf in the OPF:
leaf_node = get_node(opf4, 8)

# Get the parent node (internode) Z coordinates:
parent_zmax = zmax(leaf_node.parent)

# Define a rotation of the mesh around the Z axis defined by the parent node max Z:
transformation = recenter(Rotate(RotZ(1.0)), Point(0.0, 0.0, parent_zmax))

# Update the transformation matrix of the leaf and its mesh:
transform_mesh!(leaf_node, transformation)

# Plot the result:
viz(opf)
viz!(opf4)
```
"""
function transform_mesh!(node::MultiScaleTreeGraph.Node, transformation)
    if node[:geometry] !== nothing
        node[:geometry].transformation = node[:geometry].transformation → transformation
        # If the node has a computed mesh, update it:
        if node[:geometry].mesh !== nothing
            refmesh_to_mesh!(node)
        end
    end
end

function apply(t, x::RefMesh)
    RefMesh(x.name, apply(t, x.mesh), x.normals, x.texture_coords, x.material, x.taper)
end