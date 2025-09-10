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
    material_to_opf_string(material::Phong)
    material_to_opf_string(material::Colorant)

Format a material into a Dict for OPF writting.
"""
function material_to_opf_string(material::Phong)
    Dict(
        :emission => colorant_to_string(material.emission),
        :ambient => colorant_to_string(material.ambient),
        :diffuse => colorant_to_string(material.diffuse),
        :specular => colorant_to_string(material.specular),
        :shininess => string(material.shininess)
    )
end

function material_to_opf_string(material::Colorant)
    # Here we use the same color for all Phong parameters
    Dict(
        :emission => join(Float64[0.0, 0.0, 0.0, 0.0], "\t"),
        :ambient => colorant_to_string(material),
        :diffuse => colorant_to_string(material),
        :specular => colorant_to_string(material),
        :shininess => "1.0"
    )
end

"""
    colorant_to_string(x)

Parse a geometry material for OPF writing.
"""
function colorant_to_string(x::T) where {T<:RGBA}
    join(Float64[x.r, x.g, x.b, x.alpha], "\t")
end

function colorant_to_string(x::T) where {T<:RGB}
    join(Float64[x.r, x.g, x.b, 1.0], "\t")
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
struct RefMesh{S<:String,ME<:Meshes.Mesh{<:Meshes.𝔼{3}},M<:Union{Material,Colorant},N<:AbstractVector,T<:Union{AbstractVector,Nothing}}
    name::S
    mesh::ME
    normals::N
    texture_coords::T
    material::M
    taper::Bool
end

#! Make a method that computes the normals and texture_coords from the mesh
function RefMesh(name, mesh, material=RGB(220 / 255, 220 / 255, 220 / 255))
    RefMesh(
        name,
        mesh,
        normals_vertex(mesh),
        nothing,
        material,
        false
    )
end


# Deepcopying a RefMesh returns the same object. This is because the mesh is immutable, and because we don't want to 
# have several copies of the same refmesh for different organs.
Base.deepcopy_internal(x::RefMesh, dict::IdDict) = x
# see: https://github.com/JuliaLang/julia/blob/9acf1129c91cddd9194f529ad9cc82afd2694190/base/deepcopy.jl

"""
    Geometry(; ref_mesh<:RefMesh, transformation=Identity(), dUp=1.0, dDwn=1.0)

A Node geometry with the reference mesh, its transformation (as a function) and the resulting
mesh (optional, may be lazily computed).

The `transformation` field should be a `TransformsBase.Transform`, such as `TransformsBase.Identity`, or the ones implemented in 
`Meshes.jl`, *e.g.* `Translate`, `Scale`... If you already have the transformation matrix, you can pass it to `Meshes.Affine()`. 
"""
mutable struct Geometry{M<:RefMesh,S}
    ref_mesh::M
    transformation::Transform
    dUp::S
    dDwn::S
end

function Geometry(; ref_mesh, transformation=Identity(), dUp=1.0, dDwn=1.0)
    Geometry(
        ref_mesh,
        transformation,
        dUp,
        dDwn
    )
end