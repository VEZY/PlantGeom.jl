"""
Returns a tapered mesh using dDwn and dUp based on the geometry of an input mesh.
Tapering a mesh transforms it into a tapered version (*i.e.* pointy) or enlarged object,
*e.g.* make a cone from a cylinder.
"""
function taper(mesh, dUp, dDwn)
    if dUp != 1.0 && dDwn != 1.0 && !isnan(dUp) && !isnan(dDwn)
        mesh_points = Meshes.vertices(mesh)
        delta = dDwn - dUp
        Xs = map(x -> Meshes.coords(x).x, mesh_points)
        xmin = minimum(Xs)
        xmax = maximum(Xs)
        deltaX = xmax - xmin
        scaled_mesh = Array{eltype(mesh_points)}(undef, length(mesh_points))
        for i = 1:length(mesh_points)
            dX = (Meshes.coords(mesh_points[i]).x - xmin)
            factor = dDwn - delta * (dX / deltaX)
            p = Meshes.coords(mesh_points[i])
            scaled_mesh[i] = Meshes.Point(p.x, p.y * factor, p.z * factor)
        end
        mesh = Meshes.SimpleMesh(scaled_mesh, Meshes.topology(mesh))
    end

    return mesh
end
