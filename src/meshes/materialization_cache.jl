const _MaterializationCounts = NamedTuple{
    (:hits, :misses, :fallbacks, :evictions),NTuple{4,Int},
}
_zero_materialization_counts() = (hits=0, misses=0, fallbacks=0, evictions=0)

struct _GeometryMaterializationEntry
    signature::Any
    mesh::Any
end

"""
    GeometryMaterializationCache()

An opt-in cache of individual organ meshes for [`build_merged_mesh_with_map`](@ref).
It reuses unchanged `ExtrudedTubeGeometry` inputs with supported affine
transformations. Other geometry sources and transformations are materialized
normally. Reconstruction, callbacks, and the ordered merged mesh are never skipped.

Use one cache per logical MTG and call `empty!(cache)` when changing plant/profile.
Entries own copied numeric inputs and individual meshes, not MTG nodes. Each
successful call evicts entries absent from its selected geometry. This mutable
cache is intended for sequential use; cached inputs and meshes must not be mutated
through internal fields.
"""
mutable struct GeometryMaterializationCache
    entries::Dict{Int,_GeometryMaterializationEntry}
    last::_MaterializationCounts
    total::_MaterializationCounts
end

GeometryMaterializationCache() = GeometryMaterializationCache(
    Dict{Int,_GeometryMaterializationEntry}(),
    _zero_materialization_counts(),
    _zero_materialization_counts(),
)

"""
    empty!(cache::GeometryMaterializationCache)

Release all cached meshes and reset the last-call and cumulative counters.
"""
function Base.empty!(cache::GeometryMaterializationCache)
    empty!(cache.entries)
    cache.last = _zero_materialization_counts()
    cache.total = _zero_materialization_counts()
    return cache
end

"""
    materialization_cache_stats(cache)

Return `(entries, last, total)` counters. Hits reuse an individual mesh; misses
rebuild a supported tube; fallbacks follow the uncached path. Evictions count
previous entries absent or unsupported in the current successful selection.
"""
materialization_cache_stats(cache::GeometryMaterializationCache) = (
    entries=length(cache.entries), last=cache.last, total=cache.total,
)

struct _UnsupportedMaterializationInput end
const _UNSUPPORTED_MATERIALIZATION_INPUT = _UnsupportedMaterializationInput()

# Restrict snapshots to inert scalar/array data. In particular, do not deepcopy
# arbitrary callback-bearing geometry or evaluate an arbitrary transformation.
function _materialization_inert_type(::Type{T}) where {T}
    isbitstype(T) || return false
    T in (
        Bool, Int8, Int16, Int32, Int64, Int128,
        UInt8, UInt16, UInt32, UInt64, UInt128,
        Float16, Float32, Float64, N0f8,
    ) && return true
    trusted_container = T <: Tuple || T <: StaticArrays.SArray ||
                        T <: GeometryBasics.Point || T <: RotMatrix ||
                        T <: RotX || T <: RotY || T <: RotZ || T <: AngleAxis ||
                        T <: RGB || T <: RGBA || T <: Phong || T <: UniformScaling
    return trusted_container && all(_materialization_inert_type, fieldtypes(T))
end

function _materialization_value_snapshot(x)
    if x === nothing || _materialization_inert_type(typeof(x))
        return (typeof(x), x)
    elseif x isa Array && _materialization_inert_type(eltype(x))
        return (typeof(x), copy(x))
    end
    return _UNSUPPORTED_MATERIALIZATION_INPUT
end

_materialization_transform_snapshot(::Transformation) =
    _UNSUPPORTED_MATERIALIZATION_INPUT
_materialization_transform_snapshot(t::IdentityTransformation) = (typeof(t),)

function _materialization_transform_snapshot(t::Translation)
    translation = _materialization_value_snapshot(t.translation)
    translation === _UNSUPPORTED_MATERIALIZATION_INPUT && return translation
    return (typeof(t), translation)
end

function _materialization_transform_snapshot(t::LinearMap)
    linear = _materialization_value_snapshot(t.linear)
    linear === _UNSUPPORTED_MATERIALIZATION_INPUT && return linear
    return (typeof(t), linear)
end

function _materialization_transform_snapshot(t::AffineMap)
    linear = _materialization_value_snapshot(t.linear)
    translation = _materialization_value_snapshot(t.translation)
    if linear === _UNSUPPORTED_MATERIALIZATION_INPUT ||
       translation === _UNSUPPORTED_MATERIALIZATION_INPUT
        return _UNSUPPORTED_MATERIALIZATION_INPUT
    end
    return (typeof(t), linear, translation)
end

function _materialization_transform_snapshot(t::ComposedTransformation)
    outer = _materialization_transform_snapshot(t.t1)
    inner = _materialization_transform_snapshot(t.t2)
    if outer === _UNSUPPORTED_MATERIALIZATION_INPUT ||
       inner === _UNSUPPORTED_MATERIALIZATION_INPUT
        return _UNSUPPORTED_MATERIALIZATION_INPUT
    end
    # Preserve operator ordering rather than flattening to a matrix: the latter
    # can conceal differences in per-vertex floating-point evaluation.
    return (typeof(t), outer, inner)
end

_materialization_signature(geometry) = _UNSUPPORTED_MATERIALIZATION_INPUT

function _materialization_signature(geometry::ExtrudedTubeGeometry)
    transform = _materialization_transform_snapshot(geometry.transformation)
    transform === _UNSUPPORTED_MATERIALIZATION_INPUT && return transform
    values = map((
        geometry.path, geometry.radii, geometry.widths, geometry.heights,
        geometry.path_normals, geometry.material, geometry.radius,
    )) do value
        _materialization_value_snapshot(value)
    end
    any(value -> value === _UNSUPPORTED_MATERIALIZATION_INPUT, values) &&
        return _UNSUPPORTED_MATERIALIZATION_INPUT
    return (
        typeof(geometry), values, geometry.n_sides,
        geometry.torsion, geometry.cap_ends, transform,
    )
end

function _count_materialization!(cache::GeometryMaterializationCache, name::Symbol)
    counts = cache.last
    cache.last = merge(counts, NamedTuple{(name,)}((getproperty(counts, name) + 1,)))
    return nothing
end

function _cached_geometry_mesh!(
    cache::GeometryMaterializationCache, seen::Set{Int}, node_id::Int, geometry,
)
    signature = _materialization_signature(geometry)
    if signature === _UNSUPPORTED_MATERIALIZATION_INPUT
        _count_materialization!(cache, :fallbacks)
        return geometry_to_mesh(geometry)
    end
    push!(seen, node_id)
    entry = get(cache.entries, node_id, nothing)
    if entry !== nothing && isequal(entry.signature, signature)
        _count_materialization!(cache, :hits)
        return entry.mesh
    end
    _count_materialization!(cache, :misses)
    mesh = geometry_to_mesh(geometry)
    cache.entries[node_id] = _GeometryMaterializationEntry(signature, mesh)
    return mesh
end

function _finish_materialization!(cache::GeometryMaterializationCache, kept::Set{Int})
    for key in collect(keys(cache.entries))
        key in kept && continue
        delete!(cache.entries, key)
        _count_materialization!(cache, :evictions)
    end
    previous, current = cache.total, cache.last
    cache.total = (
        hits=previous.hits + current.hits,
        misses=previous.misses + current.misses,
        fallbacks=previous.fallbacks + current.fallbacks,
        evictions=previous.evictions + current.evictions,
    )
    return nothing
end

function _abort_materialization!(cache::GeometryMaterializationCache, previous_total)
    empty!(cache.entries)
    cache.last = _zero_materialization_counts()
    cache.total = previous_total
    return nothing
end
