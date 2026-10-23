const _FrameCacheCounts = NamedTuple{
    (:prefix_hits, :prefix_misses, :postfix_hits, :postfix_misses, :fallbacks, :evictions),
    NTuple{6,Int},
}
_zero_frame_cache_counts() = (prefix_hits=0, prefix_misses=0, postfix_hits=0,
    postfix_misses=0, fallbacks=0, evictions=0)

struct _ReconstructionFrameEntry
    signature::Any
    prefix::Any
    postfix_signature::Any
    frame::Any
end

"""
    ReconstructionFrameCache()

Experimental, opt-in cache of pure reconstruction frame arithmetic. Pass it as
`reconstruction_cache=cache` to `rebuild_geometry!`. Every orientation/bending
hook and every prototype callback still runs in its normal traversal order.
Changed local inputs, parent frames, or hook results invalidate dependent work.
Unsupported coordinate delegates, constraints, or input representations use the
ordinary reconstruction path. Entries contain copied values, never MTG nodes,
geometry objects, callbacks, or source scenes.

Use one cache per logical plant and `empty!(cache)` when changing its identity.
The mutable cache is intended for sequential use.
"""
mutable struct ReconstructionFrameCache
    entries::Dict{Int,_ReconstructionFrameEntry}
    configuration::Any
    last::_FrameCacheCounts
    total::_FrameCacheCounts
end
ReconstructionFrameCache() = ReconstructionFrameCache(
    Dict{Int,_ReconstructionFrameEntry}(), nothing,
    _zero_frame_cache_counts(), _zero_frame_cache_counts(),
)

function Base.empty!(cache::ReconstructionFrameCache)
    empty!(cache.entries)
    cache.configuration = nothing
    cache.last = _zero_frame_cache_counts()
    cache.total = _zero_frame_cache_counts()
    return cache
end

"""
    reconstruction_frame_cache_stats(cache)

Return `(entries, last, total)`. Prefix hits reuse placement/insertion arithmetic;
postfix hits reuse the final frame after executing and checking the actual hooks.
Misses recompute those stages, fallbacks take the complete ordinary path, and
evictions remove entries absent or unsupported in the current successful call.
"""
reconstruction_frame_cache_stats(cache::ReconstructionFrameCache) = (
    entries=length(cache.entries), last=cache.last, total=cache.total,
)

struct _UnsupportedFrameInput end
const _UNSUPPORTED_FRAME_INPUT = _UnsupportedFrameInput()

# Do not invoke user conversion, equality, iteration or deepcopy methods while
# deciding whether arbitrary attributes are reusable.
function _frame_value_snapshot(x)
    T = typeof(x)
    if x === nothing || x === missing || x isa Symbol || x isa String ||
       T in (Bool, Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32,
             UInt64, UInt128, Float16, Float32, Float64)
        return (T, x)
    elseif x isa Tuple || x isa NamedTuple
        values = map(_frame_value_snapshot, Tuple(x))
        any(v -> v === _UNSUPPORTED_FRAME_INPUT, values) && return _UNSUPPORTED_FRAME_INPUT
        return (T, values)
    elseif x isa Array || x isa StaticArrays.SArray
        values = map(_frame_value_snapshot, x)
        any(v -> v === _UNSUPPORTED_FRAME_INPUT, values) && return _UNSUPPORTED_FRAME_INPUT
        return (T, size(x), values)
    elseif x isa Dict
        values = Any[]
        for (k, v) in x
            a, b = _frame_value_snapshot(k), _frame_value_snapshot(v)
            (a === _UNSUPPORTED_FRAME_INPUT || b === _UNSUPPORTED_FRAME_INPUT) &&
                return _UNSUPPORTED_FRAME_INPUT
            push!(values, (a, b))
        end
        # Dict iteration order is irrelevant to configuration semantics.
        return (T, Dict(values))
    elseif T === GeometryConvention || T === AngleConvention || T === AmapReconstructionOptions
        values = Any[]
        for name in fieldnames(T)
            name in (:frame_orientation_hook, :gravity_bending_hook) && continue
            value = _frame_value_snapshot(getfield(x, name))
            value === _UNSUPPORTED_FRAME_INPUT && return value
            push!(values, (name, value))
        end
        return (T, values)
    end
    return _UNSUPPORTED_FRAME_INPUT
end

mutable struct _FrameCacheContext
    cache::ReconstructionFrameCache
    names::Set{Symbol}
    enabled::Bool
    next::Dict{Int,_ReconstructionFrameEntry}
    counts::Vector{Int}
end

function _frame_collect_names!(names, x)
    if x isa Symbol
        push!(names, x)
    elseif x isa AbstractArray || x isa Tuple
        foreach(value -> _frame_collect_names!(names, value), x)
    elseif x isa AbstractDict
        foreach(value -> _frame_collect_names!(names, value), values(x))
    elseif x isa GeometryConvention || x isa AngleConvention
        for name in fieldnames(typeof(x))
            _frame_collect_names!(names, getfield(x, name))
        end
    end
    return names
end

function _frame_cache_key(node)
    attrs = MultiScaleTreeGraph.node_attributes(node)
    if isroot(node) && !haskey(attrs, :SourceNodeID)
        return nothing
    end
    value = get(attrs, :SourceNodeID, node_id(node))
    typeof(value) === Int || return nothing
    return value
end

function _frame_cache_begin(cache::ReconstructionFrameCache, mtg, configuration,
    convention, conventions, options, aliases, coordinate_mode, warn_missing)
    names = Set{Symbol}()
    _frame_collect_names!(names, convention)
    _frame_collect_names!(names, conventions)
    _frame_collect_names!(names, aliases)
    union!(names, _TOP_WIDTH_ALIASES, _TOP_HEIGHT_ALIASES)
    for name in fieldnames(AmapReconstructionOptions)
        endswith(String(name), "_aliases") &&
            _frame_collect_names!(names, getfield(options, name))
    end
    push!(names, options.order_attribute)
    snapshot = _frame_value_snapshot(configuration)
    enabled = coordinate_mode === :topology_default && !warn_missing &&
              snapshot !== _UNSUPPORTED_FRAME_INPUT
    ids = Set{Int}()
    traverse!(mtg) do node
        key = _frame_cache_key(node)
        if key !== nothing
            key in ids && (enabled = false)
            push!(ids, key)
        end
        # A decomposition rooted at the scene is the ordinary AMAP primary
        # axis. Nested components can rewire successor anchors/propagation.
        if !isroot(node) && link(node) === :/ && !isroot(parent(node))
            enabled = false
        end
    end
    counts = zeros(Int, 6)
    if !isequal(cache.configuration, snapshot)
        counts[6] = length(cache.entries)
        empty!(cache.entries)
    end
    cache.configuration = snapshot
    return _FrameCacheContext(cache, names, enabled,
        Dict{Int,_ReconstructionFrameEntry}(), counts)
end

function _frame_attributes_snapshot(node, names)
    values = Dict{Symbol,Any}()
    for (name, value) in MultiScaleTreeGraph.node_attributes(node)
        name in names || continue
        snapshot = _frame_value_snapshot(value)
        snapshot === _UNSUPPORTED_FRAME_INPUT && return snapshot
        values[name] = snapshot
    end
    # `_try_attr` also accepts actual node fields when a mapped attribute is
    # absent. Capture only explicitly mapped fields, without evaluating
    # arbitrary properties or retaining parent/child/node objects.
    attrs = MultiScaleTreeGraph.node_attributes(node)
    for name in fieldnames(typeof(node))
        name in names && !haskey(attrs, name) || continue
        snapshot = _frame_value_snapshot(getfield(node, name))
        snapshot === _UNSUPPORTED_FRAME_INPUT && return snapshot
        values[name] = snapshot
    end
    return values
end

function _frame_cache_lookup(ctx::_FrameCacheContext, node, parent_node,
    base_pos, top_pos, direction, base_rot, options)
    key = _frame_cache_key(node)
    if !ctx.enabled || key === nothing
        ctx.counts[5] += 1
        return nothing, nothing, key
    end
    # Constraints keep a cross-node frame cache; leave their complete stage
    # untouched. Component stiffness propagation remains active on all paths.
    for name in options.geometry_constraint_aliases
        value, present = _try_attr(node, name)
        if present && value !== nothing && !ismissing(value)
            ctx.counts[5] += 1
            return nothing, nothing, key
        end
    end
    attrs = _frame_attributes_snapshot(node, ctx.names)
    parent_attrs = parent_node === nothing ? nothing :
                   _frame_attributes_snapshot(parent_node, ctx.names)
    if attrs === _UNSUPPORTED_FRAME_INPUT || parent_attrs === _UNSUPPORTED_FRAME_INPUT
        ctx.counts[5] += 1
        return nothing, nothing, key
    end
    parent_frame = parent_node === nothing ? nothing : (
        get(base_pos, parent_node, nothing), get(top_pos, parent_node, nothing),
        get(direction, parent_node, nothing), get(base_rot, parent_node, nothing),
    )
    anchor_frame = if parent_node !== nothing && link(node) === :<
        anchor = _successor_anchor_node(parent_node, top_pos)
        (_frame_cache_key(anchor), get(base_pos, anchor, nothing),
         get(top_pos, anchor, nothing), get(direction, anchor, nothing),
         get(base_rot, anchor, nothing))
    else
        nothing
    end
    siblings = parent_node === nothing ? nothing :
        [(_frame_cache_key(child), link(child), symbol(child), index(child), scale(child))
         for child in children(parent_node)]
    signature = (symbol(node), index(node), scale(node), link(node), attrs,
        parent_attrs, parent_frame, anchor_frame, siblings)
    entry = get(ctx.cache.entries, key, nothing)
    if entry !== nothing && isequal(entry.signature, signature)
        ctx.counts[1] += 1
        return entry, signature, key
    end
    ctx.counts[2] += 1
    return nothing, signature, key
end

function _frame_cache_finish!(ctx::_FrameCacheContext)
    ctx.counts[6] += count(key -> !haskey(ctx.next, key), keys(ctx.cache.entries))
    ctx.cache.entries = ctx.next
    counts = _FrameCacheCounts(Tuple(ctx.counts))
    ctx.cache.last = counts
    ctx.cache.total = _FrameCacheCounts(map(+, Tuple(ctx.cache.total), Tuple(counts)))
    return ctx.cache
end
