"""
    nvertices(meshes::RefMesh)

Return the number of vertices of a reference mesh
"""
function Meshes.nvertices(mesh::RefMesh)
    Meshes.nvertices(mesh.mesh)
end

"""
    nelements(meshes::RefMeshes)

Return the number of elements of a reference mesh
"""
function Meshes.nelements(mesh::RefMesh)
    Meshes.nelements(mesh.mesh)
end

"""
    nvertices(meshes::RefMeshes)

Return the number of vertices for each reference mesh as a vector of nvertices
"""
function Meshes.nvertices(meshes::RefMeshes)
    [Meshes.nvertices(i) for i in meshes.meshes]
    # TODO: Implement for RefMesh with GeometryBasics
end

"""
    nelements(meshes::RefMeshes)

Return the number of elements for each reference mesh as a vector of nelements
"""
function Meshes.nelements(meshes::RefMeshes)
    [Meshes.nelements(i) for i in meshes.meshes]
    # TODO: Implement for RefMesh with GeometryBasics
end
