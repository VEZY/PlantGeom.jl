"""
Data structure for a mesh material that is used to describe the light components of a [Phong reflection](https://en.wikipedia.org/wiki/Phong_reflection_model)
type model. All data is stored as RGBα for Red, Green, Blue and transparency.
"""
struct Material{T,S<:Colorant}
    emission::S
    ambiant::S
    diffuse::S
    specular::S
    shininess::T
end

"""
RefMesh type. Stores all information about a reference Mesh
"""
struct RefMesh{S<:Union{String,SubString},M<:Material}
    name::S
    normals::Vector{Float64}
    textureCoords::Vector{Float64}
    material::M
    mesh::SimpleMesh
end

"""
RefMeshes type. Stores all RefMesh.
"""
mutable struct RefMeshes
    meshes::Dict{Int,RefMesh}
end
