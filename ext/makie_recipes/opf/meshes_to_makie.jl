"""
    meshes_to_makie(mesh)

Compute the vertices and triangle faces from a Meshes.jl mesh for Makie.

Returns a tuple `(vertices, faces)` where `vertices` is a vector of 3D points (as tuples of 3 float64) and `faces` is a vector of `Makie.TriangleFace` (from `GeometryBasics`).
"""
function meshes_to_makie(mesh)
    v = map(p -> Unitful.ustrip.(Tuple(Meshes.to(p))), Meshes.eachvertex(mesh))
    t = [Makie.TriangleFace(Meshes.indices(t)) for t in Meshes.topology(mesh)]

    return v, t
end
