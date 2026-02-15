"""
    meshes_to_makie(mesh)

Extract vertices and triangular faces from a GeometryBasics mesh for Makie.
"""
function meshes_to_makie(mesh)
    v = GeometryBasics.decompose(Point3, mesh)
    t = GeometryBasics.decompose(Makie.TriangleFace{Int}, mesh)

    return v, t
end
