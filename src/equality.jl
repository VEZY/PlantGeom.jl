"""
    ==(a::RefMesh, b::RefMesh)

Test RefMesh equality.
"""
function Base.:(==)(a::T, b::T) where {T<:RefMesh}
    isequal(a.name, b.name) &&
        isequal(a.mesh, b.mesh) &&
        isequal(a.normals, b.normals) &&
        isequal(a.texture_coords, b.texture_coords) &&
        isequal(a.material, b.material) &&
        isequal(a.taper, b.taper)
end

"""
    ==(a::Geometry, b::Geometry)

Test RefMesh equality.
"""
function Base.:(==)(a::Geometry, b::Geometry)
    ta = a.transformation(SVector{3,Float64}(1, 2, 3))
    tb = b.transformation(SVector{3,Float64}(1, 2, 3))

    isequal(a.ref_mesh, b.ref_mesh) &&
        isapprox(collect(ta), collect(tb); atol=1.0e-8, rtol=1.0e-8) &&
        # NB: transform a point here because transformations can't be compared directly
        isequal(a.dUp, b.dUp) &&
        isequal(a.dDwn, b.dDwn)
end
