"""
    cylinder()

Return a reference cylinder (`RefMesh`) of 1m radius and 1m length. The cylinder axis is oriented
parallel to the z axis, and the origin (center of the bottom cap of the cylinder) is positionned
at x = 0, y = 0 and z = 0.
"""
function cylinder()
    file = joinpath(dirname(dirname(pathof(PlantGeom))), "data", "cylinder_124faces.ply")

    return RefMesh("cylinder", read_ply(file))
end

"""
    read_ply(file)

Read a ply file into a `Meshes.Meshes.SimpleMesh` format. Code taken from
[Meshes.jl](https://juliageometry.github.io/Meshes.jl/stable/algorithms/smoothing.html)
documentation.

Note: Remove when we have cylinder triangulation in Meshes.jl (and remove the dependency to PlyIO)
"""
function read_ply(file)
    ply = load_ply(file)
    x = ply["vertex"]["x"]
    y = ply["vertex"]["y"]
    z = ply["vertex"]["z"]
    points = Meshes.Point3.(x, y, z)
    connec = [Meshes.connect(Tuple(c .+ 1)) for c in ply["face"]["vertex_indices"]]
    Meshes.SimpleMesh(points, connec)
end
