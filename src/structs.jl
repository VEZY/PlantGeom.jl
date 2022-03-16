"""
A material for the illumination model (e.g. Phong illumination).
"""
abstract type Material end


"""
Data structure for a mesh material that is used to describe the light components of a [Phong reflection](https://en.wikipedia.org/wiki/Phong_reflection_model)
type model. All data is stored as RGBα for Red, Green, Blue and transparency.
"""
struct Phong{T,S<:Colorant} <: Material
    emission::S
    ambient::S
    diffuse::S
    specular::S
    shininess::T
end

"""

    RefMesh(
        name::S
        mesh::SimpleMesh
        normals::N
        texture_coords::T
        material::M
        taper::Bool
    )

    RefMesh(name, mesh, material = RGB(220 / 255, 220 / 255, 220 / 255))

RefMesh type. Stores all information about a Mesh:
- `name::S`: the mesh name
- `mesh::SimpleMesh`: the actual mesh information -> points and topology
- `normals::Vector{Float64}`: the normals, given as a vector of x1,y1,z1,x2,y2,z2...
- `texture_coords::Vector{Float64}`: the texture coordinates (not used yet), idem, a vector
- `material::M`: the material, used to set the shading
- `taper::Bool`: `true` if tapering is enabled

The reference meshes are then transformed on each node of the MTG using a transformation matrix
to match the actual mesh.
"""
struct RefMesh{S<:Union{String,SubString},M<:Union{Material,Colorant},N<:SVector,T<:Union{SVector,Nothing}}
    name::S
    mesh::Meshes.SimpleMesh
    normals::N
    texture_coords::T
    material::M
    taper::Bool
end

#! Make a method that computes the normals and texture_coords from the mesh

function RefMesh(name, mesh, material = RGB(220 / 255, 220 / 255, 220 / 255))
    RefMesh(
        name,
        SVector{length(Meshes.topology(mesh).connec)}(
            Meshes.normal(Meshes.Triangle(mesh.points[[tri.indices...]])) for tri in Meshes.topology(mesh).connec
        ),
        nothing,
        material,
        mesh,
        false
    )
end


"""
RefMeshes type. Data base that stores all [`RefMesh`](@ref) in an MTG. Usually stored in the
`:ref_meshes` attribute of the root node.
"""
mutable struct RefMeshes
    meshes::Vector{RefMesh}
end

names(m::RefMeshes) = [i.name for i in RefMeshes.meshes]

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
    mesh::Union{Meshes.SimpleMesh,Nothing}
end
