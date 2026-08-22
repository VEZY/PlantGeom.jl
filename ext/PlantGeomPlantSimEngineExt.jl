module PlantGeomPlantSimEngineExt

using PlantGeom
import PlantGeom: emit_internode!, emit_leaf!, emit_phytomer!
import PlantSimEngine
import MultiScaleTreeGraph

const PlantSimEngineRuntime = Union{
    PlantSimEngine.CompositeModel,
    PlantSimEngine.RunContext,
    PlantSimEngine.Simulation,
}

@inline PlantGeom._node_from(x::PlantSimEngine.Status) = x.node

function _emit_organ_with_scene!(
    parent::MultiScaleTreeGraph.Node,
    runtime::PlantSimEngineRuntime,
    link,
    symbol,
    scale;
    index::Integer=0,
    id=nothing,
    attributes=NamedTuple(),
    initial_status=NamedTuple(),
    kind=nothing,
    species=nothing,
    name=nothing,
    bump_scene::Bool=true,
)
    link_sym = PlantGeom._as_link_symbol(link)
    symbol_sym = PlantGeom._as_symbol(symbol)
    scale_val = isnothing(scale) ? MultiScaleTreeGraph.scale(parent) : Int(scale)
    organ_id = isnothing(id) ? nothing : Int(id)
    attrs = PlantGeom._to_attr_dict(attributes)
    status = PlantSimEngine.add_organ!(
        parent,
        runtime,
        link_sym,
        symbol_sym,
        scale_val;
        index=index,
        id=organ_id,
        attributes=attrs,
        initial_status=initial_status,
        kind=kind,
        species=species,
        name=name,
    )

    bump_scene && PlantGeom.bump_scene_version!(parent)
    return status
end

function emit_internode!(
    parent::MultiScaleTreeGraph.Node,
    runtime::PlantSimEngineRuntime;
    index::Integer=0,
    scale=nothing,
    link=:<,
    id=nothing,
    length=nothing,
    width=nothing,
    thickness=nothing,
    phyllotaxy=nothing,
    azimuth=nothing,
    y_insertion_angle=nothing,
    offset=nothing,
    border_offset=nothing,
    insertion_mode=nothing,
    x_euler=nothing,
    y_euler=nothing,
    z_euler=nothing,
    prototype=nothing,
    prototype_overrides=nothing,
    attributes=NamedTuple(),
    initial_status=NamedTuple(),
    kind=nothing,
    species=nothing,
    name=nothing,
    bump_scene::Bool=true,
    kwargs...,
)
    attrs = PlantGeom._build_internode_attrs(
        ;
        length=length,
        width=width,
        thickness=thickness,
        phyllotaxy=phyllotaxy,
        azimuth=azimuth,
        y_insertion_angle=y_insertion_angle,
        offset=offset,
        border_offset=border_offset,
        insertion_mode=insertion_mode,
        x_euler=x_euler,
        y_euler=y_euler,
        z_euler=z_euler,
        prototype=prototype,
        prototype_overrides=prototype_overrides,
        attributes=attributes,
        extra_attrs=kwargs,
    )
    return _emit_organ_with_scene!(
        parent,
        runtime,
        link,
        :Internode,
        scale;
        index=index,
        id=id,
        attributes=attrs,
        initial_status=initial_status,
        kind=kind,
        species=species,
        name=name,
        bump_scene=bump_scene,
    )
end

function emit_internode!(
    parent_status::PlantSimEngine.Status,
    runtime::PlantSimEngineRuntime;
    kwargs...,
)
    return emit_internode!(parent_status.node, runtime; kwargs...)
end

function emit_leaf!(
    parent::MultiScaleTreeGraph.Node,
    runtime::PlantSimEngineRuntime;
    index::Integer=0,
    scale=nothing,
    link=:+,
    id=nothing,
    length=nothing,
    width=nothing,
    thickness=nothing,
    phyllotaxy=nothing,
    azimuth=nothing,
    x_insertion_angle=nothing,
    y_insertion_angle=nothing,
    z_insertion_angle=nothing,
    offset=nothing,
    border_offset=nothing,
    insertion_mode=nothing,
    x_euler=nothing,
    y_euler=nothing,
    z_euler=nothing,
    prototype=nothing,
    prototype_overrides=nothing,
    attributes=NamedTuple(),
    initial_status=NamedTuple(),
    kind=nothing,
    species=nothing,
    name=nothing,
    bump_scene::Bool=true,
    kwargs...,
)
    attrs = PlantGeom._build_leaf_attrs(
        ;
        length=length,
        width=width,
        thickness=thickness,
        phyllotaxy=phyllotaxy,
        azimuth=azimuth,
        x_insertion_angle=x_insertion_angle,
        y_insertion_angle=y_insertion_angle,
        z_insertion_angle=z_insertion_angle,
        offset=offset,
        border_offset=border_offset,
        insertion_mode=insertion_mode,
        x_euler=x_euler,
        y_euler=y_euler,
        z_euler=z_euler,
        prototype=prototype,
        prototype_overrides=prototype_overrides,
        attributes=attributes,
        extra_attrs=kwargs,
    )
    return _emit_organ_with_scene!(
        parent,
        runtime,
        link,
        :Leaf,
        scale;
        index=index,
        id=id,
        attributes=attrs,
        initial_status=initial_status,
        kind=kind,
        species=species,
        name=name,
        bump_scene=bump_scene,
    )
end

function emit_leaf!(
    parent_status::PlantSimEngine.Status,
    runtime::PlantSimEngineRuntime;
    kwargs...,
)
    return emit_leaf!(parent_status.node, runtime; kwargs...)
end

function emit_phytomer!(
    parent::MultiScaleTreeGraph.Node,
    runtime::PlantSimEngineRuntime;
    internode=NamedTuple(),
    leaf=NamedTuple(),
    internode_index::Integer=0,
    leaf_index::Integer=0,
    scale=nothing,
    bump_scene::Bool=true,
)
    internode_status = if internode === nothing
        nothing
    else
        internode_kwargs = merge(
            (; index=internode_index, scale=scale, bump_scene=false),
            PlantGeom._to_nt(internode),
        )
        emit_internode!(parent, runtime; internode_kwargs...)
    end

    leaf_parent = isnothing(internode_status) ? parent : internode_status.node
    leaf_status = if leaf === nothing
        nothing
    else
        leaf_kwargs = merge(
            (; index=leaf_index, scale=scale, bump_scene=false),
            PlantGeom._to_nt(leaf),
        )
        emit_leaf!(leaf_parent, runtime; leaf_kwargs...)
    end

    bump_scene &&
        (internode_status !== nothing || leaf_status !== nothing) &&
        PlantGeom.bump_scene_version!(parent)
    return (internode=internode_status, leaf=leaf_status)
end

function emit_phytomer!(
    parent_status::PlantSimEngine.Status,
    runtime::PlantSimEngineRuntime;
    kwargs...,
)
    return emit_phytomer!(parent_status.node, runtime; kwargs...)
end

end
