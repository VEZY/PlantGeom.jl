"""
    nvertices(meshes::RefMesh)

Return the number of vertices of a reference mesh
"""
function nvertices(mesh::RefMesh)
    nvertices(mesh.mesh)
end

"""
    nelements(meshes::RefMeshes)

Return the number of elements of a reference mesh
"""
function nelements(mesh::RefMesh)
    nelements(mesh.mesh)
end

"""
    nvertices(meshes::RefMeshes)

Return the number of vertices for each reference mesh as a vector of nvertices
"""
function nvertices(meshes::RefMeshes)
    [nvertices(i) for i in meshes.meshes]
end

"""
    nelements(meshes::RefMeshes)

Return the number of elements for each reference mesh as a vector of nelements
"""
function nelements(meshes::RefMeshes)
    [nelements(i) for i in meshes.meshes]
end
