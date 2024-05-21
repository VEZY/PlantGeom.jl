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
struct RefMesh{S<:String,ME<:Meshes.SimpleMesh,M<:Union{Material,Colorant},N<:AbstractVector,T<:Union{AbstractVector,Nothing}}
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


"""
RefMeshes type. Data base that stores all [`RefMesh`](@ref) in an MTG. Usually stored in the
`:ref_meshes` attribute of the root node.
"""
mutable struct RefMeshes
    meshes::Vector{RefMesh}
end

Base.names(m::RefMeshes) = [i.name for i in m.meshes]

"""
    geometry(; ref_mesh<:RefMesh, ref_mesh_index=nothing, transformation=Identity(), dUp=1.0, dDwn=1.0, mesh::Union{SimpleMesh,Nothing}=nothing)

A Node geometry with the reference mesh, its transformation (as a function) and optionnally the
index of the reference mesh in the reference meshes data base (see notes) and the resulting
mesh (optional to save memory).

# Note

The ref_mesh usually points to a [`RefMesh`](@ref) stored in the `:ref_meshes` attribute of the
root node of the MTG.

Although optional, storing the index of the reference mesh (`ref_mesh_index`) in the database allows a faster
writing of the MTG as an OPF to disk.

The `transformation` field should be a function, such as a `Meshes.jl`'s transformation. In case
no transformation is needed, use `TransformsBase.Identity`. If you already have the
transformation matrix, you can pass it to `Meshes.Affine()`. If you prefer using `CoordinateTransformations.jl`,
you can wrap the transformation object in a function, *e.g.* `x -> transform(x)`.

```julia
mat = randn(4, 4)
transformation = x -> Meshes.Point3((Translation(@view mat[1:3, 4]) ∘ LinearMap(@view mat[1:3, 1:3]))(x.coords))
```

Note that the wrapping serves two purposes: use the point coordinates directly because `CoordinateTransformations.jl`
does not have a method for `Meshes.jl` types, and to return the result as a `Meshes.Point3` type.
"""
mutable struct geometry{M<:RefMesh,S}
    ref_mesh::M
    ref_mesh_index::Union{Int,Nothing}
    transformation::Union{Function,GeometricTransform,Identity}
    dUp::S
    dDwn::S
    mesh::Union{Meshes.SimpleMesh,Nothing}
end

function geometry(; ref_mesh, ref_mesh_index=nothing, transformation=Identity(), dUp=1.0, dDwn=1.0, mesh=nothing)
    geometry(
        ref_mesh,
        ref_mesh_index,
        transformation,
        dUp,
        dDwn,
        mesh
    )
end

function geometry(ref_mesh, ref_mesh_index=nothing)
    geometry(; ref_mesh=ref_mesh, ref_mesh_index=ref_mesh_index)
end