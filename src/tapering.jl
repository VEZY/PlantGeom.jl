"""
Returns a tapered mesh using dDwn and dUp based on the geometry of an input mesh.
Tapering a mesh transforms it into a tapered version (*i.e.* pointy) or enlarged object,
*e.g.* make a cone from a cylinder.
"""
function taper(mesh, dUp, dDwn)
    if dUp != 1.0 && dDwn != 1.0
        mesh_points = mesh.points
        delta = dDwn - dUp
        Xs = map(x -> x.coords[1], mesh_points)
        xmin = minimum(Xs)
        xmax = maximum(Xs)
        deltaX = xmax - xmin

        scaled_mesh = Array{Point3}(undef, length(mesh_points))
        for i = 1:length(mesh_points)
            dX = (mesh_points[i].coords[1] - xmin)
            factor = dDwn - delta * (dX / deltaX)
            scaled_mesh[i] = Point3(
                mesh_points[i].coords[1],
                mesh_points[i].coords[2] * factor,
                mesh_points[i].coords[3] * factor
            )
        end
        mesh = SimpleMesh(scaled_mesh, mesh.topology)
    end

    return mesh
end
