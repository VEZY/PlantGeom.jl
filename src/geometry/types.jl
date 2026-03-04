"""
    Geometry(; ref_mesh<:RefMesh, transformation=IdentityTransformation(), dUp=1.0, dDwn=1.0)

A node geometry backed by a shared `RefMesh` plus a per-node transformation.

This is the classic OPF-style "instantiate once, transform many" geometry
source. The materialized mesh is computed lazily via [`geometry_to_mesh`](@ref).
"""
mutable struct Geometry{M<:RefMesh,T<:Transformation,S}
    ref_mesh::M
    transformation::T
    dUp::S
    dDwn::S
end

function Geometry(; ref_mesh, transformation=IdentityTransformation(), dUp=1.0, dDwn=1.0, mesh=nothing)
    mesh !== nothing && @warn "The `mesh` argument is deprecated and will be removed in future versions. The mesh is now computed on-the-fly using `refmesh_to_mesh(node)`."
    Geometry(
        ref_mesh,
        transformation,
        dUp,
        dDwn
    )
end

"""
    PointMappedGeometry(ref_mesh, point_map; params=nothing, transformation=IdentityTransformation())

Geometry source that deforms a `RefMesh` by applying `point_map` to each local vertex.

Use this for non-affine per-vertex mappings while keeping the classic `Geometry`
path optimized for affine-style instancing. `point_map` is called as
`point_map(point, params)` when that method exists, otherwise as `point_map(point)`.
After the local deformation, the optional `transformation` is applied.
"""
struct PointMappedGeometry{M<:RefMesh,F,P,T<:Transformation}
    ref_mesh::M
    point_map::F
    params::P
    transformation::T
end

function PointMappedGeometry(ref_mesh::M, point_map::F; params=nothing, transformation=IdentityTransformation()) where {M<:RefMesh,F}
    PointMappedGeometry{M,F,typeof(params),typeof(transformation)}(
        ref_mesh,
        point_map,
        params,
        transformation,
    )
end

"""
    ExtrudedTubeGeometry(path;
        n_sides=8,
        radius=0.5,
        radii=nothing,
        widths=nothing,
        heights=nothing,
        path_normals=nothing,
        torsion=true,
        cap_ends=false,
        material=RGB(220 / 255, 220 / 255, 220 / 255),
        transformation=IdentityTransformation())

Procedural geometry source backed by [`extrude_tube_mesh`](@ref).

Unlike [`Geometry`](@ref), this source does not reference a pre-existing
`RefMesh`; the mesh is rebuilt from its path/section parameters whenever
materialized (for example by scene merging).
"""
struct ExtrudedTubeGeometry{P,R,RV,WV,HV,NV,M,T<:Transformation}
    path::P
    n_sides::Int
    radius::R
    radii::RV
    widths::WV
    heights::HV
    path_normals::NV
    torsion::Bool
    cap_ends::Bool
    material::M
    transformation::T
end

function ExtrudedTubeGeometry(
    path::AbstractVector;
    n_sides::Integer=8,
    radius::Real=0.5,
    radii=nothing,
    widths=nothing,
    heights=nothing,
    path_normals=nothing,
    torsion::Bool=true,
    cap_ends::Bool=false,
    material::Union{Material,Colorant}=RGB(220 / 255, 220 / 255, 220 / 255),
    transformation::Transformation=IdentityTransformation(),
)
    ExtrudedTubeGeometry(
        path,
        Int(n_sides),
        Float64(radius),
        radii,
        widths,
        heights,
        path_normals,
        torsion,
        cap_ends,
        material,
        transformation,
    )
end
