"""
    nvertices(meshes::RefMesh)

Return the number of vertices of a reference mesh.
"""
function nvertices(mesh::RefMesh)
    _nvertices(mesh.mesh)
end

"""
    nelements(meshes::RefMesh)

Return the number of triangular elements of a reference mesh.
"""
function nelements(mesh::RefMesh)
    _nfaces(mesh.mesh)
end

function nvertices(mesh)
    _nvertices(mesh)
end

function nelements(mesh)
    _nfaces(mesh)
end

function normals(mesh::RefMesh)
    if length(mesh.normals) == 0
        verts = _vertices(mesh.mesh)
        [face_normal(verts[f[1]], verts[f[2]], verts[f[3]]) for f in _faces(mesh.mesh)]
    else
        mesh.normals
    end
end

"""
    normals_vertex(mesh)

Compute per vertex normals and return them as `GeometryBasics.Vec{3,Float64}`.
"""
function normals_vertex(mesh::RefMesh)
    normals_vertex(mesh.mesh)
end

function normals_vertex(mesh)
    zero_vec = vec3(0.0, 0.0, 0.0)
    verts = _vertices(mesh)
    faces = _faces(mesh)
    vertex_normals = fill(zero_vec, length(verts))

    for f in faces
        n = face_normal(verts[f[1]], verts[f[2]], verts[f[3]])
        vertex_normals[f[1]] = n
        vertex_normals[f[2]] = n
        vertex_normals[f[3]] = n
    end

    vertex_normals
end
