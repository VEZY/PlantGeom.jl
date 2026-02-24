"""
Returns a tapered mesh using dDwn and dUp based on the geometry of an input mesh.
Tapering a mesh transforms it into a tapered version (*i.e.* pointy) or enlarged object,
*e.g.* make a cone from a cylinder.
"""
function taper(mesh, dUp, dDwn)
    if dUp != 1.0 && dDwn != 1.0 && !isnan(dUp) && !isnan(dDwn)
        mesh_points = _vertices(mesh)
        delta = dDwn - dUp
        Xs = map(p -> p[1], mesh_points)
        xmin = minimum(Xs)
        xmax = maximum(Xs)
        deltaX = xmax - xmin

        scaled_mesh = Vector{GeometryBasics.Point{3,Float64}}(undef, length(mesh_points))
        for i in eachindex(mesh_points)
            p = mesh_points[i]
            dX = p[1] - xmin
            factor = dDwn - delta * (dX / deltaX)
            scaled_mesh[i] = point3(p[1], p[2] * factor, p[3] * factor)
        end

        mesh = _mesh(scaled_mesh, _faces(mesh))
    end

    return mesh
end
