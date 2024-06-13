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
    ==(a::RefMeshes, b::RefMeshes)

Test RefMeshes equality.
"""
function Base.:(==)(a::T, b::T) where {T<:RefMeshes}
    isequal(names(a), names(b)) &&
        all([isequal(a.meshes[i], b.meshes[i]) for i in 1:length(a.meshes)])
end


"""
    ==(a::geometry, b::geometry)

Test RefMeshes equality.
"""
function Base.:(==)(a::T, b::T) where {T<:geometry}
    isequal(a.ref_mesh, b.ref_mesh) &&
        isequal(a.ref_mesh_index, b.ref_mesh_index) &&
        isequal(a.transformation(Meshes.Point(1, 2, 3)), b.transformation(Meshes.Point(1, 2, 3))) &&
        # NB: transform a point here because transformations can't be compared directly
        isequal(a.dUp, b.dUp) &&
        isequal(a.dDwn, b.dDwn) &&
        isequal(a.mesh, b.mesh)
end
