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
    transform_mesh(node::Node, transformation)

Add a new `CoordinateTransformations.jl` transformation to the node geometry
`transformation` field. The transformation is composed with the previous
transformation if any.

It is also possible to invert a transformation using `inv` from
`CoordinateTransformations.jl`.
"""
function transform_mesh(node::MultiScaleTreeGraph.Node, transformation)
    node[:geometry].transformation = node[:geometry].transformation ∘ transformation
end

"""
    transform_mesh(node::geometry, transformation)

Transform a geometry using a transformation.
NB: updates the mesh of the geometry only if it exists already
"""
function transform_mesh(x::geometry, transformation)
    # generic method that does not update the "mesh" field (doe not exist yet)
    rotation_mat = transform(x.ref_mesh, transformation)
    x.transformation_matrix = rotation_mat * x.transformation_matrix
    #! This is pseudo code. Check how the computation is really made
    return nothing
end

"""
    transform_mesh(x::T, rotation) where {T<:RefMesh}

Transform a RefMesh based on transformation.
"""
function transform_mesh(x::T, transformation) where {T<:RefMesh}
    transform_mesh(x.mesh, transformation)
end


"""
    transform_mesh(x::T, rotation) where {T<:SimpleMesh}

Rotate a SimpleMesh based on rotation
"""
function transform_mesh(x::T, transformation) where {T<:SimpleMesh}

    #! put code that rotates a mesh based on rotation
    #! This function should be replaced as soon as Meshes.jl implements it
end


"""
    rotate!(node::Node, rotation)

Rotate a node using rotation.
"""
function rotate!(node::MultiScaleTreeGraph.Node, rotation)
    rotate!(node[:geometry], rotation)
end

"""
    rotate!(node::geometry, rotation)

Rotate a geometry using rotation.
NB: updates the mesh of the geometry only if it exists already
"""
function rotate!(x::geometry, rotation)
    # generic method that does not update the "mesh" field (doe not exist yet)
    rotation_mat = rotate(x.ref_mesh, rotation)
    x.transformation_matrix = rotation_mat * x.transformation_matrix
    #! This is pseudo code. Check how the computation is really made
    return nothing
end

# method that updates the "mesh" field if it exists
function rotate!(x::geometry{R,T,S} where {R,T,S,L,M<:SimpleMesh})
    rotation_mat = rotate(x.ref_mesh, rotation)
    x.transformation_matrix = rotation_mat * x.transformation_matrix

    for (i, p) in enumerate(ref_mesh.points)
        scaled_mesh[i] = Point3((node[:geometry].transformation_matrix*vcat(p.coords, 1.0))[1:3])
    end

    #! This is pseudo code. Check how the computation is really made
end

"""
    rotate(x::T, rotation) where {T<:RefMesh}

Rotate a RefMesh based on rotation.
"""
function rotate(x::T, rotation) where {T<:RefMesh}
    rotate(x.mesh, rotation)
end

"""
    rotate(x::T, rotation) where {T<:SimpleMesh}

Rotate a SimpleMesh based on rotation
"""
function rotate(x::T, rotation) where {T<:SimpleMesh}
    #! put code that rotates a mesh based on rotation
    #! This function should be replaced as soon as Meshes.jl implements it
end

function scale(x)

end

function translate(x)

end
