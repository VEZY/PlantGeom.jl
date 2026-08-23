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

struct _CompiledSourceOwnerMap <:
       AbstractDict{PlantGeom.SourceOwnerKey,PlantSimEngine.ObjectId}
    owner_keys::Vector{PlantGeom.SourceOwnerKey}
    object_ids::Vector{PlantSimEngine.ObjectId}
    index::Dict{PlantGeom.SourceOwnerKey,Int}
    scene_mtg::WeakRef
    model::WeakRef
    scene_revision::Int
    model_revision::Int
end

Base.length(owner_map::_CompiledSourceOwnerMap) = length(owner_map.owner_keys)
Base.keys(owner_map::_CompiledSourceOwnerMap) = Base.KeySet(owner_map)
Base.values(owner_map::_CompiledSourceOwnerMap) = Base.ValueIterator(owner_map)
Base.haskey(owner_map::_CompiledSourceOwnerMap, key::PlantGeom.SourceOwnerKey) =
    haskey(owner_map.index, key)

@inline function Base.getindex(
    owner_map::_CompiledSourceOwnerMap,
    key::PlantGeom.SourceOwnerKey,
)
    position = owner_map.index[key]
    return @inbounds owner_map.object_ids[position]
end

@inline function Base.iterate(owner_map::_CompiledSourceOwnerMap, state::Int=1)
    state > length(owner_map.owner_keys) && return nothing
    return (
        @inbounds(owner_map.owner_keys[state] => owner_map.object_ids[state]),
        state + 1,
    )
end

@inline _source_owner_sort_key(key::PlantGeom.SourceOwnerKey) =
    (key.source_instance_id, key.source_node_id)

function _normalized_source_owner_keys(scene::PlantGeom.SceneGeometry, owner_keys)
    available = Set{PlantGeom.SourceOwnerKey}()
    for node in values(scene.nodes)
        owner = node.source_owner
        owner === nothing || push!(available, owner)
    end

    selected = if owner_keys === nothing
        collect(available)
    else
        requested = owner_keys isa PlantGeom.SourceOwnerKey ? (owner_keys,) : owner_keys
        normalized = Set{PlantGeom.SourceOwnerKey}()
        for key in requested
            key isa PlantGeom.SourceOwnerKey || throw(ArgumentError(
                "`owner_keys` must contain only SourceOwnerKey values; got $(typeof(key)).",
            ))
            key in available || throw(ArgumentError(
                "Source owner $key is not present in the prepared scene.",
            ))
            push!(normalized, key)
        end
        collect(normalized)
    end
    sort!(selected; by=_source_owner_sort_key)
    return selected
end

function _insert_exact_owner_node!(owner_nodes, key, node)
    previous = get(owner_nodes, key, nothing)
    if previous !== nothing && previous !== node
        throw(ArgumentError(
            "Source owner $key matches more than one node in its exact MTG root. " *
            "Source owner ids must be unique inside one source instance.",
        ))
    end
    owner_nodes[key] = node
    return nothing
end

function _require_all_owner_nodes!(owner_nodes, owner_keys, context)
    for key in owner_keys
        haskey(owner_nodes, key) && continue
        throw(ArgumentError(
            "Source owner $key has no exact MTG node in $context. " *
            "Pass `object_resolver` when an owner key does not denote an MTG node.",
        ))
    end
    return owner_nodes
end

function _scene_owner_nodes(scene::PlantGeom.SceneGeometry, owner_keys, model)
    # This call is intentionally identity-based. It rejects a copied or foreign
    # scene even when its raw MTG ids happen to match the registered model.
    PlantSimEngine.object_id(model, scene.mtg)

    wanted = Set(owner_keys)
    owner_nodes = Dict{PlantGeom.SourceOwnerKey,Any}()
    for source_root in PlantGeom._scene_source_roots(scene.mtg)
        source_instance_id = PlantGeom._scene_positive_int_attribute(
            source_root,
            PlantGeom._SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
        )
        source_instance_id === nothing && throw(ArgumentError(
            "The prepared scene contains a source root without a source-instance namespace.",
        ))
        MultiScaleTreeGraph.traverse!(source_root) do node
            key = PlantGeom.SourceOwnerKey(
                source_instance_id,
                PlantGeom._intrinsic_source_node_id(node),
            )
            key in wanted && _insert_exact_owner_node!(owner_nodes, key, node)
            return nothing
        end
    end
    return _require_all_owner_nodes!(owner_nodes, owner_keys, "`scene.mtg`")
end

_source_root_entries(source_roots::Pair) = (source_roots,)
_source_root_entries(source_roots::Union{AbstractDict,NamedTuple,Base.Pairs}) =
    pairs(source_roots)
_source_root_entries(source_roots) = source_roots

function _normalized_source_roots(source_roots, model)
    roots = Dict{Int,MultiScaleTreeGraph.Node}()
    for entry in _source_root_entries(source_roots)
        entry isa Pair || throw(ArgumentError(
            "`source_roots` must be a mapping or iterable of `instance_id => exact_mtg_root` pairs.",
        ))
        raw_instance_id, root = entry
        raw_instance_id isa Integer || throw(ArgumentError(
            "Source-root instance ids must be integers; got $(typeof(raw_instance_id)).",
        ))
        instance_id = Int(raw_instance_id)
        instance_id > 0 || throw(ArgumentError(
            "Source-root instance ids must be positive; got $instance_id.",
        ))
        root isa MultiScaleTreeGraph.Node || throw(ArgumentError(
            "Source root $instance_id must be an exact MTG Node; got $(typeof(root)).",
        ))
        haskey(roots, instance_id) && throw(ArgumentError(
            "`source_roots` contains source instance $instance_id more than once.",
        ))
        # Normalize through PlantSimEngine so copied and unregistered roots are
        # rejected by the runtime's exact source identity index.
        PlantSimEngine.object_id(model, root)
        roots[instance_id] = root
    end
    return roots
end

function _explicit_root_owner_nodes(source_roots, owner_keys, model)
    roots = _normalized_source_roots(source_roots, model)
    wanted_by_instance = Dict{Int,Set{Int}}()
    for key in owner_keys
        push!(
            get!(wanted_by_instance, key.source_instance_id, Set{Int}()),
            key.source_node_id,
        )
    end

    owner_nodes = Dict{PlantGeom.SourceOwnerKey,Any}()
    for (source_instance_id, wanted_ids) in wanted_by_instance
        root = get(roots, source_instance_id, nothing)
        root === nothing && throw(ArgumentError(
            "`source_roots` has no exact MTG root for source instance $source_instance_id.",
        ))
        MultiScaleTreeGraph.traverse!(root) do node
            source_node_id = PlantGeom._intrinsic_source_node_id(node)
            source_node_id in wanted_ids || return nothing
            key = PlantGeom.SourceOwnerKey(source_instance_id, source_node_id)
            _insert_exact_owner_node!(owner_nodes, key, node)
            return nothing
        end
    end
    return _require_all_owner_nodes!(owner_nodes, owner_keys, "`source_roots`")
end

function _resolved_object_id(model, object_resolver, key)
    applicable(object_resolver, key) || throw(ArgumentError(
        "`object_resolver` must be callable with one SourceOwnerKey; got $(typeof(object_resolver)).",
    ))
    source = object_resolver(key)
    try
        # Deliberately never construct ObjectId from the callback result here.
        # object_id validates raw ids and exact Object/Status/MTG identities.
        return PlantSimEngine.object_id(model, source)
    catch error
        error isa InterruptException && rethrow()
        throw(ArgumentError(
            "`object_resolver` returned an invalid destination for source owner $key: " *
            sprint(showerror, error),
        ))
    end
end

function _validate_owner_map_compile_state!(
    scene,
    runtime,
    model,
    scene_mtg,
    scene_revision,
    model_revision,
)
    PlantSimEngine.runtime_model(runtime) === model || error(
        "The PlantSimEngine runtime changed while compiling source ownership.",
    )
    scene.mtg === scene_mtg || error(
        "The SceneGeometry MTG changed while compiling source ownership.",
    )
    PlantGeom.scene_version(scene) == scene_revision || error(
        "The scene version changed while compiling source ownership; retry with the refreshed scene.",
    )
    PlantSimEngine.Advanced.model_revision(model) == model_revision || error(
        "The PlantSimEngine topology changed while compiling source ownership; refresh bindings and retry.",
    )
    PlantSimEngine.Advanced.bindings_dirty(model) && error(
        "PlantSimEngine bindings became dirty while compiling source ownership; refresh bindings and retry.",
    )
    return nothing
end

"""
    compile_source_owner_map(scene, runtime; owner_keys=nothing,
                             source_roots=nothing, object_resolver=nothing)

Compile the scene's opaque source-owner keys to validated PlantSimEngine
`ObjectId`s. The returned dictionary is read-only and iterates in sorted
`SourceOwnerKey` order.

By default, owners are resolved only against the exact `scene.mtg` registered
by `runtime`. Use `source_roots=Dict(instance_id => exact_mtg_root)` when the
simulation owns the original source MTGs instead of the assembled scene copy,
or `object_resolver=key -> object` for a non-MTG ownership scheme. Resolver
results always pass through `PlantSimEngine.object_id`.
"""
function PlantGeom.compile_source_owner_map(
    scene::PlantGeom.SceneGeometry,
    runtime::PlantSimEngineRuntime;
    owner_keys=nothing,
    source_roots=nothing,
    object_resolver=nothing,
)
    source_roots !== nothing && object_resolver !== nothing && throw(ArgumentError(
        "`source_roots` and `object_resolver` are mutually exclusive.",
    ))

    model = PlantSimEngine.runtime_model(runtime)
    PlantSimEngine.Advanced.bindings_dirty(model) && throw(ArgumentError(
        "Source-owner compilation requires clean PlantSimEngine bindings. " *
        "Compile or refresh the CompositeModel before building the map.",
    ))
    scene_mtg = scene.mtg
    scene_mtg === nothing && throw(ArgumentError(
        "Source-owner compilation requires an MTG-backed SceneGeometry.",
    ))
    scene_revision = PlantGeom.scene_version(scene)
    model_revision = PlantSimEngine.Advanced.model_revision(model)
    selected_keys = _normalized_source_owner_keys(scene, owner_keys)

    object_ids = PlantSimEngine.ObjectId[]
    sizehint!(object_ids, length(selected_keys))
    if object_resolver !== nothing
        for key in selected_keys
            push!(object_ids, _resolved_object_id(model, object_resolver, key))
        end
    else
        owner_nodes = source_roots === nothing ?
                      _scene_owner_nodes(scene, selected_keys, model) :
                      _explicit_root_owner_nodes(source_roots, selected_keys, model)
        for key in selected_keys
            # Node identities, like callback results, are normalized and
            # validated by PlantSimEngine rather than converted from raw ids.
            push!(object_ids, PlantSimEngine.object_id(model, owner_nodes[key]))
        end
    end

    index = Dict{PlantGeom.SourceOwnerKey,Int}(
        key => position for (position, key) in enumerate(selected_keys)
    )
    _validate_owner_map_compile_state!(
        scene,
        runtime,
        model,
        scene_mtg,
        scene_revision,
        model_revision,
    )
    return _CompiledSourceOwnerMap(
        selected_keys,
        object_ids,
        index,
        WeakRef(scene_mtg),
        WeakRef(model),
        scene_revision,
        model_revision,
    )
end

@inline function PlantGeom.source_owner_map_iscurrent(
    owner_map::_CompiledSourceOwnerMap,
)
    scene_mtg = owner_map.scene_mtg.value
    model = owner_map.model.value
    scene_mtg === nothing && return false
    model === nothing && return false
    return PlantGeom.scene_version(scene_mtg) == owner_map.scene_revision &&
           PlantSimEngine.Advanced.model_revision(model) == owner_map.model_revision &&
           !PlantSimEngine.Advanced.bindings_dirty(model)
end

@inline function PlantGeom.source_owner_map_iscurrent(
    owner_map::_CompiledSourceOwnerMap,
    scene::PlantGeom.SceneGeometry,
    runtime::PlantSimEngineRuntime,
)
    model = PlantSimEngine.runtime_model(runtime)
    owner_map.scene_mtg.value === scene.mtg || return false
    owner_map.model.value === model || return false
    return PlantGeom.scene_version(scene) == owner_map.scene_revision &&
           PlantSimEngine.Advanced.model_revision(model) == owner_map.model_revision &&
           !PlantSimEngine.Advanced.bindings_dirty(model)
end

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
