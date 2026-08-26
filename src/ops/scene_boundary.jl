"""
    scene_boundary_mesh(scene::MultiScaleTreeGraph.Node)

Build a planar mesh for the extent stored in `scene[:scene_dimensions]` without
modifying `scene`. The mesh is a visualization aid for OPS scenes: it is not a
botanical organ, scientific ground, or radiative surface.

Use `plantviz(scene; show_scene_boundary=true)` for the standard outline
overlay. Add real ground geometry separately with [`add_ground!`](@ref).
"""
function scene_boundary_mesh(scene::MultiScaleTreeGraph.Node)
    root = MultiScaleTreeGraph.get_root(scene)
    haskey(root, :scene_dimensions) || throw(
        ArgumentError("cannot build a scene boundary without scene_dimensions"),
    )

    scene_dimensions = root[:scene_dimensions]
    isnothing(scene_dimensions) && throw(
        ArgumentError("cannot build a scene boundary when scene_dimensions is nothing"),
    )
    scene_dimensions isa Tuple && length(scene_dimensions) == 2 || throw(
        ArgumentError("scene_dimensions must contain an origin and an opposite corner"),
    )

    p_0, p_max = scene_dimensions
    coordinates = (
        Float64(p_0[1]),
        Float64(p_0[2]),
        Float64(p_0[3]),
        Float64(p_max[1]),
        Float64(p_max[2]),
    )
    all(isfinite, coordinates) || throw(
        ArgumentError("scene_dimensions must contain only finite coordinates"),
    )

    x_0, x_max = extrema((coordinates[1], coordinates[4]))
    y_0, y_max = extrema((coordinates[2], coordinates[5]))
    x_0 < x_max || throw(ArgumentError("scene boundary width must be positive"))
    y_0 < y_max || throw(ArgumentError("scene boundary depth must be positive"))
    z = coordinates[3]

    points = [
        point3(x_0, y_0, z),
        point3(x_max, y_0, z),
        point3(x_max, y_max, z),
        point3(x_0, y_max, z),
    ]
    faces = [face3(1, 2, 3), face3(3, 4, 1)]
    return _mesh(points, faces)
end
