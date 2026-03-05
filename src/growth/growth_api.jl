@inline function _as_link_symbol(link)
    if link isa Symbol
        link in (:<, :+, :/) || error("Invalid link '$link'. Expected one of :<, :+ or :/.")
        return link
    elseif link isa AbstractString
        return _as_link_symbol(Symbol(link))
    elseif link isa Char
        return _as_link_symbol(Symbol(link))
    end
    error("Invalid link type $(typeof(link)). Expected Symbol, String, or Char.")
end

@inline _node_from(x::MultiScaleTreeGraph.Node) = x

@inline _default_scale(parent::MultiScaleTreeGraph.Node) = MultiScaleTreeGraph.scale(parent)
@inline _default_id(parent::MultiScaleTreeGraph.Node) = MultiScaleTreeGraph.new_id(MultiScaleTreeGraph.get_root(parent))

function _to_attr_dict(attrs)
    d = Dict{Symbol,Any}()
    if attrs === nothing
        return d
    elseif attrs isa NamedTuple || attrs isa Base.Pairs || attrs isa AbstractDict
        for (k, v) in pairs(attrs)
            d[_as_symbol(k)] = v
        end
        return d
    elseif attrs isa Tuple || attrs isa AbstractVector
        for item in attrs
            item isa Pair || error("Unsupported attributes element $(typeof(item)); expected Pair.")
            d[_as_symbol(first(item))] = last(item)
        end
        return d
    end
    error("Unsupported attributes container $(typeof(attrs)). Use NamedTuple, Dict, or keyword pairs.")
end

@inline function _set_if_not_nothing!(attrs::Dict{Symbol,Any}, key::Symbol, value)
    value === nothing && return attrs
    attrs[key] = value
    return attrs
end

function _apply_growth_attrs!(node::MultiScaleTreeGraph.Node, attrs::NamedTuple)
    for (k, v) in pairs(attrs)
        node[_as_symbol(k)] = v
    end
    return node
end

function _apply_growth_attrs!(node::MultiScaleTreeGraph.Node, attrs::AbstractDict)
    for (k, v) in pairs(attrs)
        node[_as_symbol(k)] = v
    end
    return node
end

function _build_internode_attrs(;
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
    attributes=NamedTuple(),
    extra_attrs=NamedTuple(),
)
    attrs = Dict{Symbol,Any}()
    phyllotaxy_val = phyllotaxy === nothing ? azimuth : phyllotaxy
    _set_if_not_nothing!(attrs, :Length, length)
    _set_if_not_nothing!(attrs, :Width, width)
    thickness_val = thickness === nothing && width !== nothing ? width : thickness
    _set_if_not_nothing!(attrs, :Thickness, thickness_val)
    _set_if_not_nothing!(attrs, :Phyllotaxy, phyllotaxy_val)
    _set_if_not_nothing!(attrs, :YInsertionAngle, y_insertion_angle)
    _set_if_not_nothing!(attrs, :Offset, offset)
    _set_if_not_nothing!(attrs, :BorderInsertionOffset, border_offset)
    _set_if_not_nothing!(attrs, :InsertionMode, insertion_mode)
    _set_if_not_nothing!(attrs, :XEuler, x_euler)
    _set_if_not_nothing!(attrs, :YEuler, y_euler)
    _set_if_not_nothing!(attrs, :ZEuler, z_euler)
    merge!(attrs, _to_attr_dict(extra_attrs))
    merge!(attrs, _to_attr_dict(attributes))
    return attrs
end

function _build_leaf_attrs(;
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
    attributes=NamedTuple(),
    extra_attrs=NamedTuple(),
)
    attrs = Dict{Symbol,Any}()
    phyllotaxy_val = phyllotaxy === nothing ? azimuth : phyllotaxy
    _set_if_not_nothing!(attrs, :Length, length)
    _set_if_not_nothing!(attrs, :Width, width)
    thickness_val = thickness === nothing && width !== nothing ? width : thickness
    _set_if_not_nothing!(attrs, :Thickness, thickness_val)
    _set_if_not_nothing!(attrs, :Phyllotaxy, phyllotaxy_val)
    _set_if_not_nothing!(attrs, :XInsertionAngle, x_insertion_angle)
    _set_if_not_nothing!(attrs, :YInsertionAngle, y_insertion_angle)
    _set_if_not_nothing!(attrs, :ZInsertionAngle, z_insertion_angle)
    _set_if_not_nothing!(attrs, :Offset, offset)
    _set_if_not_nothing!(attrs, :BorderInsertionOffset, border_offset)
    _set_if_not_nothing!(attrs, :InsertionMode, insertion_mode)
    _set_if_not_nothing!(attrs, :XEuler, x_euler)
    _set_if_not_nothing!(attrs, :YEuler, y_euler)
    _set_if_not_nothing!(attrs, :ZEuler, z_euler)
    merge!(attrs, _to_attr_dict(extra_attrs))
    merge!(attrs, _to_attr_dict(attributes))
    return attrs
end

function _emit_organ!(
    parent::MultiScaleTreeGraph.Node,
    link,
    symbol,
    scale;
    index::Integer=0,
    id=nothing,
    attributes=NamedTuple(),
    bump_scene::Bool=true,
)
    link_sym = _as_link_symbol(link)
    symbol_sym = _as_symbol(symbol)
    scale_val = isnothing(scale) ? _default_scale(parent) : Int(scale)
    organ_id = isnothing(id) ? _default_id(parent) : Int(id)
    attrs = _to_attr_dict(attributes)

    new_node = MultiScaleTreeGraph.Node(
        organ_id,
        parent,
        MultiScaleTreeGraph.NodeMTG(link_sym, symbol_sym, Int(index), scale_val),
        attrs,
    )

    bump_scene && bump_scene_version!(parent)
    return new_node
end

function emit_internode!(parent::MultiScaleTreeGraph.Node;
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
    attributes=NamedTuple(),
    bump_scene::Bool=true,
    kwargs...,
)
    attrs = _build_internode_attrs(
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
        attributes=attributes,
        extra_attrs=kwargs,
    )
    _emit_organ!(parent, link, :Internode, scale; index=index, id=id, attributes=attrs, bump_scene=bump_scene)
end

function emit_leaf!(parent::MultiScaleTreeGraph.Node;
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
    attributes=NamedTuple(),
    bump_scene::Bool=true,
    kwargs...,
)
    attrs = _build_leaf_attrs(
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
        attributes=attributes,
        extra_attrs=kwargs,
    )
    _emit_organ!(parent, link, :Leaf, scale; index=index, id=id, attributes=attrs, bump_scene=bump_scene)
end

@inline _to_nt(x::NamedTuple) = x
function _to_nt(x::AbstractDict)
    d = Dict{Symbol,Any}()
    for (k, v) in pairs(x)
        d[_as_symbol(k)] = v
    end
    (; d...)
end
_to_nt(::Nothing) = NamedTuple()

function emit_phytomer!(
    parent::MultiScaleTreeGraph.Node;
    internode=NamedTuple(),
    leaf=NamedTuple(),
    internode_index::Integer=0,
    leaf_index::Integer=0,
    scale=nothing,
    bump_scene::Bool=true,
)
    internode_node = if internode === nothing
        nothing
    else
        internode_kwargs = merge((; index=internode_index, scale=scale, bump_scene=false), _to_nt(internode))
        emit_internode!(parent; internode_kwargs...)
    end

    leaf_parent = isnothing(internode_node) ? parent : internode_node
    leaf_node = if leaf === nothing
        nothing
    else
        leaf_kwargs = merge((; index=leaf_index, scale=scale, bump_scene=false), _to_nt(leaf))
        emit_leaf!(leaf_parent; leaf_kwargs...)
    end

    bump_scene && (internode_node !== nothing || leaf_node !== nothing) && bump_scene_version!(parent)
    return (internode=internode_node, leaf=leaf_node)
end

@inline function _numeric_attr(node::MultiScaleTreeGraph.Node, key::Symbol, default::Float64)
    haskey(node, key) || return default
    value = node[key]
    value isa Number || return default
    return Float64(value)
end

function set_growth_attributes!(x; bump_scene::Bool=true, kwargs...)
    node = _node_from(x)
    _apply_growth_attrs!(node, kwargs)
    bump_scene && bump_scene_version!(node)
    return x
end

function set_growth_attributes!(x, attrs::NamedTuple; bump_scene::Bool=true)
    node = _node_from(x)
    _apply_growth_attrs!(node, attrs)
    bump_scene && bump_scene_version!(node)
    return x
end

function set_growth_attributes!(x, attrs::AbstractDict; bump_scene::Bool=true)
    node = _node_from(x)
    _apply_growth_attrs!(node, attrs)
    bump_scene && bump_scene_version!(node)
    return x
end

function grow_length!(x; delta, bump_scene::Bool=true)
    node = _node_from(x)
    node[:Length] = _numeric_attr(node, :Length, 0.0) + Float64(delta)
    bump_scene && bump_scene_version!(node)
    return x
end

function grow_width!(x; delta, thickness_policy::Symbol=:follow_width, bump_scene::Bool=true)
    thickness_policy in (:follow_width, :preserve, :match_increment) ||
        error("Invalid `thickness_policy` '$thickness_policy'. Expected :follow_width, :preserve, or :match_increment.")

    node = _node_from(x)
    width_new = _numeric_attr(node, :Width, 0.0) + Float64(delta)
    node[:Width] = width_new

    if thickness_policy == :follow_width
        node[:Thickness] = width_new
    elseif thickness_policy == :match_increment
        node[:Thickness] = _numeric_attr(node, :Thickness, 0.0) + Float64(delta)
    end

    bump_scene && bump_scene_version!(node)
    return x
end

function rebuild_geometry!(
    mtg::MultiScaleTreeGraph.Node,
    ref_meshes::AbstractDict;
    convention=default_amap_geometry_convention(),
    conventions=Dict(),
    offset_aliases=[:Offset, :offset],
    border_offset_aliases=[:BorderInsertionOffset, :border_insertion_offset, :BorderOffset, :border_offset],
    insertion_mode_aliases=[:InsertionMode, :insertion_mode],
    phyllotaxy_aliases=[:Phyllotaxy, :phyllotaxy, :PHYLLOTAXY],
    verticil_mode=:rotation360,
    amap_options=default_amap_reconstruction_options(),
    ref_mesh_selector::Union{Nothing,Function}=nothing,
    dUp=1.0,
    dDwn=1.0,
    warn_missing=false,
    root_align=true,
    bump_scene::Bool=true,
)
    reconstruct_geometry_from_attributes!(
        mtg,
        ref_meshes;
        convention=convention,
        conventions=conventions,
        offset_aliases=offset_aliases,
        border_offset_aliases=border_offset_aliases,
        insertion_mode_aliases=insertion_mode_aliases,
        phyllotaxy_aliases=phyllotaxy_aliases,
        verticil_mode=verticil_mode,
        amap_options=amap_options,
        ref_mesh_selector=ref_mesh_selector,
        dUp=dUp,
        dDwn=dDwn,
        warn_missing=warn_missing,
        root_align=root_align,
    )
    bump_scene && bump_scene_version!(mtg)
    return mtg
end
