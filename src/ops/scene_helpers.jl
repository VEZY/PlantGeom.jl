@inline function _scene_point3(pos::GeometryBasics.Point{3})
    point3(Float64(pos[1]), Float64(pos[2]), Float64(pos[3]))
end

@inline function _scene_point3(pos::NTuple{3,<:Real})
    point3(Float64(pos[1]), Float64(pos[2]), Float64(pos[3]))
end

function _scene_point3(pos::AbstractVector{<:Real})
    length(pos) == 3 || error("`pos` must have exactly 3 coordinates, got $(length(pos)).")
    point3(Float64(pos[1]), Float64(pos[2]), Float64(pos[3]))
end

function _scene_object_root(node::MultiScaleTreeGraph.Node)
    current = node
    while !isroot(current)
        parent_node = parent(current)
        symbol(parent_node) == :Scene && return current
        current = parent_node
    end
    return current
end

function _relabel_node_ids!(root, next_node_id::Base.RefValue{Int})
    traverse!(root) do node
        setfield!(node, :id, next_node_id[])
        next_node_id[] += 1
    end
    return nothing
end

function _ops_inclination_linear_map(inclination_azimut::Real, inclination_angle::Real)
    abs(Float64(inclination_angle)) <= eps(Float64) && return nothing

    axis = SVector(
        -sin(Float64(inclination_azimut)),
        cos(Float64(inclination_azimut)),
        0.0,
    )
    axis_norm = norm(axis)
    axis_norm > eps(Float64) || return nothing
    axis_u = axis / axis_norm

    LinearMap(RotMatrix(AngleAxis(Float64(inclination_angle), axis_u[1], axis_u[2], axis_u[3])))
end

"""
    scene_object_transformation(; pos=point3(0.0, 0.0, 0.0), scale=1.0, rotation=0.0,
                                  inclination_azimut=0.0, inclination_angle=0.0)

Build the placement transform used by OPS scenes.

The transform order matches [`read_ops`](@ref): local object geometry is first
rotated around `Z`, then uniformly scaled, then inclined, and finally translated
to `pos`.
"""
function scene_object_transformation(;
    pos=point3(0.0, 0.0, 0.0),
    scale::Real=1.0,
    rotation::Real=0.0,
    inclination_azimut::Real=0.0,
    inclination_angle::Real=0.0,
)
    pos_pt = _scene_point3(pos)
    transformation = IdentityTransformation()

    if rotation != 0.0
        transformation = LinearMap(RotZ(Float64(rotation))) ∘ transformation
    end

    if scale != 1.0
        transformation = LinearMap(Diagonal(SVector(Float64(scale), Float64(scale), Float64(scale)))) ∘ transformation
    end

    inclination_map = _ops_inclination_linear_map(inclination_azimut, inclination_angle)
    if !isnothing(inclination_map)
        transformation = inclination_map ∘ transformation
    end

    if pos_pt != point3(0.0, 0.0, 0.0)
        transformation = Translation(pos_pt[1], pos_pt[2], pos_pt[3]) ∘ transformation
    end

    return transformation
end

function _apply_scene_transformation!(object_root::MultiScaleTreeGraph.Node, scene_transformation)
    traverse!(object_root, filter_fun=node -> has_geometry(node)) do node
        transform_mesh!(node, scene_transformation)
    end
    return object_root
end

"""
    place_in_scene!(object_root;
        scene=nothing,
        scene_id=nothing,
        plant_id=nothing,
        functional_group=nothing,
        pos=nothing,
        scale=nothing,
        rotation=nothing,
        inclination_azimut=nothing,
        inclination_angle=nothing,
        file_path=nothing,
        apply_transform=true,
        rebind_scene=true)

Attach or update one plant/object inside a scene using the same placement
metadata as OPS (`sceneID`, `plantID`, `pos`, `scale`, `rotation`,
`inclinationAzimut`, `inclinationAngle`, `functional_group`, `filePath`).

By default the corresponding transform is also applied to the object geometry in
memory and stored as `scene_transformation`, which keeps `plantviz(scene)` and
`write_ops(scene)` consistent.
"""
function place_in_scene!(
    object_root::MultiScaleTreeGraph.Node;
    scene::Union{Nothing,MultiScaleTreeGraph.Node}=nothing,
    scene_id=nothing,
    plant_id=nothing,
    functional_group=nothing,
    pos=nothing,
    scale=nothing,
    rotation=nothing,
    inclination_azimut=nothing,
    inclination_angle=nothing,
    file_path=nothing,
    apply_transform::Bool=true,
    rebind_scene::Bool=true,
)
    object_root = _scene_object_root(object_root)
    scene_root = isnothing(scene) ? nothing : get_root(scene)

    scene_root === object_root && error("`scene` must be the scene root, not the object being placed.")
    if !isnothing(scene_root) && typeof(node_mtg(scene_root)) != typeof(node_mtg(object_root))
        error(
            "`scene` and `object_root` must use the same MTG encoding type. " *
            "Construct the scene with $(nameof(typeof(node_mtg(object_root)))) or read objects with a matching `mtg_type`."
        )
    end

    attrs = node_attributes(object_root)

    hasproperty(object_root, :scene_transformation) &&
        _apply_scene_transformation!(object_root, inv(object_root.scene_transformation))

    scene_id_val = isnothing(scene_id) ? (haskey(attrs, :sceneID) ? Int(attrs[:sceneID]) : 1) : Int(scene_id)
    plant_id_val = if isnothing(plant_id)
        if haskey(attrs, :plantID)
            Int(attrs[:plantID])
        elseif !isnothing(scene_root)
            length(children(scene_root)) + 1
        else
            1
        end
    else
        Int(plant_id)
    end

    pos_val = isnothing(pos) ? (haskey(attrs, :pos) ? _scene_point3(attrs[:pos]) : point3(0.0, 0.0, 0.0)) : _scene_point3(pos)
    scale_val = isnothing(scale) ? (haskey(attrs, :scale) ? Float64(attrs[:scale]) : 1.0) : Float64(scale)
    rotation_val = isnothing(rotation) ? (haskey(attrs, :rotation) ? Float64(attrs[:rotation]) : 0.0) : Float64(rotation)
    inclination_azimut_val = isnothing(inclination_azimut) ? (haskey(attrs, :inclinationAzimut) ? Float64(attrs[:inclinationAzimut]) : 0.0) : Float64(inclination_azimut)
    inclination_angle_val = isnothing(inclination_angle) ? (haskey(attrs, :inclinationAngle) ? Float64(attrs[:inclinationAngle]) : 0.0) : Float64(inclination_angle)
    functional_group_val = isnothing(functional_group) ? string(get(attrs, :functional_group, "")) : string(functional_group)

    object_root.sceneID = scene_id_val
    object_root.plantID = plant_id_val
    object_root.functional_group = functional_group_val
    object_root.pos = pos_val
    object_root.scale = scale_val
    object_root.rotation = rotation_val
    object_root.inclinationAzimut = inclination_azimut_val
    object_root.inclinationAngle = inclination_angle_val

    if !isnothing(file_path)
        object_root.filePath = string(file_path)
    end

    if apply_transform
        transformation = scene_object_transformation(
            ;
            pos=pos_val,
            scale=scale_val,
            rotation=rotation_val,
            inclination_azimut=inclination_azimut_val,
            inclination_angle=inclination_angle_val,
        )
        transformation != IdentityTransformation() && _apply_scene_transformation!(object_root, transformation)
        object_root.scene_transformation = transformation
    else
        pop!(attrs, :scene_transformation, nothing)
    end

    if !isnothing(scene_root)
        if isroot(object_root) || parent(object_root) !== scene_root
            next_node_id = Ref(max_id(scene_root) + 1)
            _relabel_node_ids!(object_root, next_node_id)
            addchild!(scene_root, object_root)
        end
    end

    if !isnothing(scene_root) && rebind_scene
        MultiScaleTreeGraph.columnarize!(scene_root)
    end

    return object_root
end
