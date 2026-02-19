"""
    meshes_to_makie(mesh)

Extract vertices and triangular faces from a GeometryBasics mesh for Makie.
"""
function meshes_to_makie(mesh)
    v = GeometryBasics.decompose(GeometryBasics.Point{3,Float64}, mesh)
    t = GeometryBasics.decompose(Makie.TriangleFace{Int}, mesh)

    return v, t
end
