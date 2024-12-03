"""
    nvertices(meshes::RefMesh)

Return the number of vertices of a reference mesh
"""
function Meshes.nvertices(mesh::RefMesh)
    Meshes.nvertices(mesh.mesh)
end

"""
    nelements(meshes::RefMesh)

Return the number of elements of a reference mesh
"""
function Meshes.nelements(mesh::RefMesh)
    Meshes.nelements(mesh.mesh)
end

function normals(mesh::RefMesh{S,ME,M,N,T}) where {S,ME<:Meshes.SimpleMesh,M,N,T}
    if length(mesh.normals) == 0
        return SVector{length(mesh.mesh)}(Meshes.normal(tri) for tri in mesh.mesh)
    else
        return mesh.normals
    end
    # TODO: Implement for RefMesh with GeometryBasics
end

"""
    normals_vertex(mesh::Meshes.SimpleMesh)

Compute per vertex normals and return them as a `StaticArrays.SVector`.

#! This is a naive approach because I have no time right know.
#! We just put the face mesh as a vertex mesh (and ovewritting values for common points)
# TODO: Use a real computation instead. See e.g.:
# https://stackoverflow.com/questions/45477806/general-method-for-calculating-smooth-vertex-normals-with-100-smoothness?noredirect=1&lq=1
"""
function normals_vertex(mesh::RefMesh)
    normals_vertex(mesh.mesh)
end

function normals_vertex(mesh::Meshes.SimpleMesh)
    vertex_normals = fill(Meshes.Vec(0.0, 0.0, 0.0), Meshes.nvertices(mesh))
    tri_normals = [Meshes.normal(tri) for tri in mesh]

    for (i, tri) in enumerate(Meshes.topology(mesh))
        tri_indices = Meshes.indices(tri)
        vertex_normals[tri_indices[1]] = tri_normals[i]
        vertex_normals[tri_indices[2]] = tri_normals[i]
        vertex_normals[tri_indices[3]] = tri_normals[i]
    end

    return SVector{length(vertex_normals)}(vertex_normals)
end