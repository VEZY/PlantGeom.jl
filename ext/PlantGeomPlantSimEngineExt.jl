module PlantGeomPlantSimEngineExt

using PlantGeom
import PlantGeom: emit_internode!, emit_leaf!, emit_phytomer!
import PlantSimEngine
import MultiScaleTreeGraph

@inline PlantGeom._node_from(x::PlantSimEngine.Status) = x.node

function _emit_organ_with_sim!(
    parent::MultiScaleTreeGraph.Node,
    sim::PlantSimEngine.GraphSimulation,
    link,
    symbol,
    scale;
    index::Integer=0,
    id=nothing,
    attributes=NamedTuple(),
    check::Bool=true,
    bump_scene::Bool=true,
)
    link_sym = PlantGeom._as_link_symbol(link)
    symbol_sym = PlantGeom._as_symbol(symbol)
    scale_val = isnothing(scale) ? MultiScaleTreeGraph.scale(parent) : Int(scale)
    organ_id = isnothing(id) ? PlantGeom._default_id(parent) : Int(id)
    attrs = PlantGeom._to_attr_dict(attributes)

    st = PlantSimEngine.add_organ!(
        parent,
        sim,
        link_sym,
        symbol_sym,
        scale_val;
        index=index,
        id=organ_id,
        attributes=attrs,
        check=check,
    )

    bump_scene && PlantGeom.bump_scene_version!(parent)
    return st
end

function emit_internode!(parent::MultiScaleTreeGraph.Node, sim::PlantSimEngine.GraphSimulation;
    index::Integer=0,
    scale=nothing,
    link=:<,
    id=nothing,
    length=nothing,
    width=nothing,
    thickness=nothing,
    phyllotaxy=nothing,
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
    check::Bool=true,
    bump_scene::Bool=true,
    kwargs...,
)
    attrs = PlantGeom._build_internode_attrs(
        ;
        length=length,
        width=width,
        thickness=thickness,
        phyllotaxy=phyllotaxy,
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
    _emit_organ_with_sim!(
        parent,
        sim,
        link,
        :Internode,
        scale;
        index=index,
        id=id,
        attributes=attrs,
        check=check,
        bump_scene=bump_scene,
    )
end

function emit_internode!(parent_status::PlantSimEngine.Status, sim::PlantSimEngine.GraphSimulation; kwargs...)
    emit_internode!(parent_status.node, sim; kwargs...)
end

function emit_leaf!(parent::MultiScaleTreeGraph.Node, sim::PlantSimEngine.GraphSimulation;
    index::Integer=0,
    scale=nothing,
    link=:+,
    id=nothing,
    length=nothing,
    width=nothing,
    thickness=nothing,
    phyllotaxy=nothing,
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
    check::Bool=true,
    bump_scene::Bool=true,
    kwargs...,
)
    attrs = PlantGeom._build_leaf_attrs(
        ;
        length=length,
        width=width,
        thickness=thickness,
        phyllotaxy=phyllotaxy,
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
    _emit_organ_with_sim!(
        parent,
        sim,
        link,
        :Leaf,
        scale;
        index=index,
        id=id,
        attributes=attrs,
        check=check,
        bump_scene=bump_scene,
    )
end

function emit_leaf!(parent_status::PlantSimEngine.Status, sim::PlantSimEngine.GraphSimulation; kwargs...)
    emit_leaf!(parent_status.node, sim; kwargs...)
end

function emit_phytomer!(
    parent::MultiScaleTreeGraph.Node,
    sim::PlantSimEngine.GraphSimulation;
    internode=NamedTuple(),
    leaf=NamedTuple(),
    internode_index::Integer=0,
    leaf_index::Integer=0,
    scale=nothing,
    check::Bool=true,
    bump_scene::Bool=true,
)
    internode_status = if internode === nothing
        nothing
    else
        internode_kwargs = merge((; index=internode_index, scale=scale, check=check, bump_scene=false), PlantGeom._to_nt(internode))
        emit_internode!(parent, sim; internode_kwargs...)
    end

    leaf_parent = isnothing(internode_status) ? parent : internode_status.node
    leaf_status = if leaf === nothing
        nothing
    else
        leaf_kwargs = merge((; index=leaf_index, scale=scale, check=check, bump_scene=false), PlantGeom._to_nt(leaf))
        emit_leaf!(leaf_parent, sim; leaf_kwargs...)
    end

    bump_scene && (internode_status !== nothing || leaf_status !== nothing) && PlantGeom.bump_scene_version!(parent)
    return (internode=internode_status, leaf=leaf_status)
end

function emit_phytomer!(
    parent_status::PlantSimEngine.Status,
    sim::PlantSimEngine.GraphSimulation;
    kwargs...
)
    emit_phytomer!(parent_status.node, sim; kwargs...)
end

end
