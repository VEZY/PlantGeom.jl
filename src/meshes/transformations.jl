#! Transformations of the meshes. Uses:
#! LinearAlgebra.UniformScaling for scaling
#! Rotation.jl for rotation
#! CoordinateTransformations.jl for translation
# Voir https://stackoverflow.com/questions/10546320/remove-rotation-from-a-4x4-homogeneous-transformation-matrix
# pour extraire la rotation et la translation depuis la matrice 4*4, puis transformer
# cette matrice 4*4 en CoordinateTransformations.jl transformations et après on ne gèrera
# que ces transformations là.

function degree_to_radian(x)
    x / (180 / π)
end

function radian_to_degree(x)
    x * (180 / π)
end

"""
    transform_mesh!(node::Node, transformation)

Add a new `CoordinateTransformations.jl` transformation to the node geometry
`transformation` field. The transformation is composed with the previous
transformation if any.

`transformation` must be a `CoordinateTransformations.jl` transformation.

It is also possible to invert a transformation using `inv` from
`CoordinateTransformations.jl`.

# Examples

```julia
using PlantGeom, MultiScaleTreeGraph, GLMakie
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)

viz(opf)

opf2 = deepcopy(opf)
transform!(opf2, x -> transform_mesh!(x, Translation(0, 15, 0)))
transform!(opf2, refmesh_to_mesh!)

viz!(opf2)
```
"""
function transform_mesh!(node::MultiScaleTreeGraph.Node, transformation)
    if node[:geometry] !== nothing
        node[:geometry].transformation = transformation ∘ node[:geometry].transformation
    end
end
