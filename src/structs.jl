"""
Data structure for a mesh material that is used to describe the light components of a [Phong reflection](https://en.wikipedia.org/wiki/Phong_reflection_model)
type model. All data is stored as RGBα for Red, Green, Blue and transparency.
"""
struct Material{T,S<:Colorant}
    emission::S
    ambient::S
    diffuse::S
    specular::S
    shininess::T
end

"""
RefMesh type. Stores all information about a Mesh:
- `name::S`: the mesh name
- `normals::Vector{Float64}`: the normals, given as a vector of x1,y1,z1,x2,y2,z2...
- `textureCoords::Vector{Float64}`: the texture coordinates (not used yet), idem, a vector
- `material::M`: the material, used to set the shading
- `mesh::SimpleMesh`: the actual mesh information -> points and topology
- `taper::Bool`: `true` if tapering is enabled


"""
struct RefMesh{S<:Union{String,SubString},M<:Material}
    name::S
    normals::Vector{Float64}
    textureCoords::Vector{Float64}
    material::M
    mesh::SimpleMesh
    taper::Bool
end

#! Make a method that computes the normals and textureCoords from the mesh

"""
RefMeshes type. Data base that stores all [`RefMesh`](@ref) in an MTG. Usually stored in the
`:ref_meshes` attribute of the root node.
"""
mutable struct RefMeshes
    meshes::Vector{RefMesh}
end

"""
    geometry(
        ref_mesh::M
        ref_mesh_index::Union{Int,Nothing}
        transformation::T
        dUp::S
        dDwn::S
        mesh::Union{SimpleMesh,Nothing}
    )

A Node geometry with the reference mesh, its transformation matrix and optionnally the
index of the reference mesh in the reference meshes data base (see notes) and the resulting
mesh (optional to save memory).

# Note

The ref_mesh usually points to a [`RefMesh`](@ref) stored in the `:ref_meshes` attribute of the
root node of the MTG.

Although optinal, storing the index of the reference mesh (`ref_mesh_index`) in the database allows a faster
writing of the MTG as an OPF to disk.

If no transformation matrix is needed, you can use `I` from the Linear Algebra package (lazy)

The `transformation` field should a `CoordinateTransformations.jl`'s transformation. In case
no transformation is needed, use `IdentityTransformation()`. If you already have the
transformation matrix, you can pass it to `LinearMap()`.
"""
mutable struct geometry{M<:RefMesh,S}
    ref_mesh::M
    ref_mesh_index::Union{Int,Nothing}
    transformation::Transformation #! replace by concrete types ?
    dUp::S
    dDwn::S
    mesh::Union{SimpleMesh,Nothing}
end
