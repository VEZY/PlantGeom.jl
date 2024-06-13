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

function normals(mesh::RefMesh{S,ME,M,N,T}) where {S,ME<:Meshes.SimpleMesh,M,N,T}
    if length(mesh.normals) == 0
        return SVector{length(Meshes.topology(mesh.mesh).connec)}(
            Meshes.Point(Meshes.normal(Meshes.Triangle(Meshes.vertices(mesh.mesh)[[tri.indices...]]))) for tri in Meshes.topology(mesh.mesh).connec
        )
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
    vertex_normals = fill(Meshes.Vec(0.0, 0.0, 0.0), Meshes.nvertices(mesh))
    for (i, tri) in enumerate(Meshes.topology(mesh.mesh).connec)
        vertex_normals[tri.indices[1]] = mesh.normals[i]
        vertex_normals[tri.indices[2]] = mesh.normals[i]
        vertex_normals[tri.indices[3]] = mesh.normals[i]
    end

    return SVector{length(vertex_normals)}(vertex_normals)
end

function normals_vertex(mesh::Meshes.SimpleMesh)
    vertex_normals = fill(Meshes.Vec(0.0, 0.0, 0.0), Meshes.nvertices(mesh))
    for (i, tri) in enumerate(Meshes.topology(mesh).connec)
        tri_norm = Meshes.normal(Meshes.Triangle(mesh.vertices[[tri.indices...]]...))
        vertex_normals[tri.indices[1]] = tri_norm
        vertex_normals[tri.indices[2]] = tri_norm
        vertex_normals[tri.indices[3]] = tri_norm
    end

    return SVector{length(vertex_normals)}(vertex_normals)
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
