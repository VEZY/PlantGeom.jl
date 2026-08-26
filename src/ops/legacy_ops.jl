"""
Compatibility helpers for visualizing OPS scenes as they appeared in historical
PlantGeom releases.

Ordinary workflows should keep the `:Scene` root geometry-free and add real
ground geometry with [`PlantGeom.add_ground!`](@ref).
"""
module LegacyOPS

using ..PlantGeom: Geometry, RefMesh, RGBA, _mesh, face3, has_geometry, point3

"""
    materialize_scene_boundary!(scene)

Attach the historical translucent OPS plot-boundary quadrangle to the `:Scene`
root. This is a visualization compatibility artifact, not scientific ground
geometry. A scene with root geometry cannot be passed to
[`PlantGeom.prepare_scene`](@ref); prefer [`PlantGeom.add_ground!`](@ref) in new
code. This mutating compatibility helper is deprecated and will be removed in
PlantGeom v0.21; use `plantviz(scene; show_scene_boundary=true)` or
[`PlantGeom.scene_boundary_mesh`](@ref) instead.
"""
function materialize_scene_boundary!(scene)
    Base.depwarn(
        "`LegacyOPS.materialize_scene_boundary!` is deprecated because it mutates " *
        "the MTG with visualization geometry. Use `plantviz(scene; " *
        "show_scene_boundary=true)` or `scene_boundary_mesh(scene)` instead; " *
        "the mutating helper will be removed in PlantGeom v0.21.",
        :materialize_scene_boundary!,
    )
    has_geometry(scene) && throw(
        ArgumentError(
            "cannot materialize the legacy OPS boundary: the Scene root already has geometry",
        ),
    )
    haskey(scene, :scene_dimensions) || throw(
        ArgumentError("cannot materialize the legacy OPS boundary without scene_dimensions"),
    )

    scene_dimensions = scene[:scene_dimensions]
    isnothing(scene_dimensions) && throw(
        ArgumentError(
            "cannot materialize the legacy OPS boundary when scene_dimensions is nothing",
        ),
    )

    p_0, p_max = scene_dimensions
    points = [
        point3(p_0),
        point3(p_max[1], p_0[2], p_0[3]),
        point3(p_max),
        point3(p_0[1], p_max[2], p_0[3]),
    ]
    faces = [face3(1, 2, 3), face3(3, 4, 1)]
    quadrangle = _mesh(points, faces)
    material = RGBA(159 / 255, 182 / 255, 205 / 255, 0.1)
    scene.geometry = Geometry(ref_mesh=RefMesh("Scene", quadrangle, material))
    return scene
end

end
