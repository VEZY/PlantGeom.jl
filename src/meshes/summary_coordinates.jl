xmax(x::Node) = has_geometry(x) ? xmax(refmesh_to_mesh(x)) : nothing
xmin(x::Node) = has_geometry(x) ? xmin(refmesh_to_mesh(x)) : nothing
ymax(x::Node) = has_geometry(x) ? ymax(refmesh_to_mesh(x)) : nothing
ymin(x::Node) = has_geometry(x) ? ymin(refmesh_to_mesh(x)) : nothing
zmax(x::Node) = has_geometry(x) ? zmax(refmesh_to_mesh(x)) : nothing
zmin(x::Node) = has_geometry(x) ? zmin(refmesh_to_mesh(x)) : nothing

xmax(x) = map_coord(maximum, x, 1)
xmin(x) = map_coord(minimum, x, 1)
ymax(x) = map_coord(maximum, x, 2)
ymin(x) = map_coord(minimum, x, 2)
zmax(x) = map_coord(maximum, x, 3)
zmin(x) = map_coord(minimum, x, 3)

"""
    xmax(x)
    ymax(x)
    zmax(x)

Get the maximum x, y or z coordinates of a mesh or a Node.
"""
xmax, ymax, zmax

"""
    xmin(x)
    ymin(x)
    zmin(x)

Get the minimum x, y or z coordinates of a mesh or a Node.
"""
xmin, ymin, zmin

"""
    map_coord(f, mesh, coord)

Apply function `f` over the mesh coordinates `coord`.
Values for `coord` can be 1 for x, 2 for y and 3 for z.
"""
function map_coord(f, mesh, coord)
    f([p[coord] for p in _vertices(mesh)])
end
