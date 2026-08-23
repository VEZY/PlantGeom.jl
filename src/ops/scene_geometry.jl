struct _NoSourceOwnerToken end

"""
    SourceOwnerKey(source_instance_id, source_node_id)

Opaque identity of the botanical source owner of one scene element.

The pair remains distinct from both the current scene MTG node id and mesh-face
indices. `source_instance_id` namespaces one object insertion in a scene, while
`source_node_id` identifies the owning node inside that source object. Several
scene elements may intentionally share one key, for example leaflet meshes
owned by a compound `Leaf`.

Treat the complete key as the identity contract; the integer fields are an
efficient scene-local representation rather than globally persistent ids.
"""
struct SourceOwnerKey
    source_instance_id::Int
    source_node_id::Int

    function SourceOwnerKey(source_instance_id::Int, source_node_id::Int)
        source_instance_id > 0 || throw(ArgumentError(
            "`source_instance_id` must be positive, got $source_instance_id.",
        ))
        source_node_id > 0 || throw(ArgumentError(
            "`source_node_id` must be positive, got $source_node_id.",
        ))
        return new(source_instance_id, source_node_id)
    end

    # Reserved for SceneNodeData's backwards-compatible `nothing` sentinel.
    SourceOwnerKey(::_NoSourceOwnerToken) = new(0, 0)
end

SourceOwnerKey(source_instance_id::Integer, source_node_id::Integer) =
    SourceOwnerKey(Int(source_instance_id), Int(source_node_id))

Base.:(==)(a::SourceOwnerKey, b::SourceOwnerKey) =
    a.source_instance_id == b.source_instance_id && a.source_node_id == b.source_node_id
Base.isequal(a::SourceOwnerKey, b::SourceOwnerKey) =
    isequal(a.source_instance_id, b.source_instance_id) &&
    isequal(a.source_node_id, b.source_node_id)
Base.hash(key::SourceOwnerKey, h::UInt) =
    hash(key.source_node_id, hash(key.source_instance_id, h))

const _NO_SOURCE_OWNER = SourceOwnerKey(_NoSourceOwnerToken())

struct _SceneSourceOwnership
    source_instance_id::Int
    source_node_id::Int
    owner_node_id::Int
end

const _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE = :_scene_source_instance_id
const _SCENE_SOURCE_OWNERSHIP_ATTRIBUTE = :_scene_source_ownership
const _SCENE_SOURCE_OWNER_RESOLVER_ATTRIBUTE = :_scene_source_owner_resolver

"""
    SceneNodeData

Generic per-node geometry summary used by [`SceneGeometry`](@ref).

The data contains geometry summaries and an opaque source-owner identity.
Semantic attributes such as `group`, `type`, cultivar, treatment, or material
class stay on the source MTG nodes. Downstream models can read and compile those
attributes during their own preparation step.

Fields:

- `area`: total triangle area associated with one MTG node, or `nothing` when
  area computation was disabled.
- `barycenter`: area-weighted 3D barycenter `(x, y, z)`, or `nothing` when
  barycenter computation was disabled.
- `source_topology_id`: original topology id copied from the source object when
  available. If no explicit source id exists, [`prepare_scene`](@ref) falls back
  to the current node id when `source_topology_id=true`.
- `source_owner`: botanical source owner of the scene element. This remains
  available independently of `source_topology_id` output retention.
"""
struct SceneNodeData{T}
    area::Union{Nothing,T}
    barycenter::Union{Nothing,NTuple{3,T}}
    source_topology_id::Union{Nothing,Int}
    source_owner::SourceOwnerKey
end

# Preserve the public constructor used by downstream synthetic-scene fixtures.
SceneNodeData(area, barycenter, source_topology_id) =
    SceneNodeData(area, barycenter, source_topology_id, _NO_SOURCE_OWNER)
SceneNodeData{T}(area, barycenter, source_topology_id) where {T} =
    SceneNodeData{T}(area, barycenter, source_topology_id, _NO_SOURCE_OWNER)
SceneNodeData(area, barycenter, source_topology_id, ::Nothing) =
    SceneNodeData(area, barycenter, source_topology_id, _NO_SOURCE_OWNER)
SceneNodeData{T}(area, barycenter, source_topology_id, ::Nothing) where {T} =
    SceneNodeData{T}(area, barycenter, source_topology_id, _NO_SOURCE_OWNER)

@inline function Base.getproperty(node::SceneNodeData, name::Symbol)
    if name === :source_owner
        owner = getfield(node, :source_owner)
        return owner == _NO_SOURCE_OWNER ? nothing : owner
    end
    return getfield(node, name)
end

"""
    SceneGeometry

Prepared generic scene representation.

It stores the source MTG, a merged mesh, a face-to-node map, optional per-node
geometry summaries, the source path, the scene XY domain, and the units used to
interpret its numeric coordinates.

Fields:

- `mtg`: scene MTG root. Its children are placed object roots or generated
  ground cells.
- `merged_mesh`: one mesh built from all geometry-bearing nodes in the scene.
- `face2node`: vector mapping each face in `merged_mesh` to the MTG node id that
  produced it.
- `nodes`: dictionary from MTG node id to [`SceneNodeData`](@ref).
- `source_path`: descriptive path or label for provenance.
- `scene_xy_bounds`: scene domain as `(xmin, ymin, xmax, ymax)`, or `nothing`
  when no domain is known.
- `units`: metadata describing the physical length unit of scene coordinates.
"""
mutable struct SceneGeometry{MTG,Mesh,T}
    mtg::MTG
    merged_mesh::Mesh
    face2node::Vector{Int}
    nodes::Dict{Int,SceneNodeData{T}}
    source_path::String
    scene_xy_bounds::Union{Nothing,NTuple{4,T}}
    units::SceneUnits
end

# Keep both historical six-argument constructors. Scene units are metadata, so
# legacy callers continue to produce metre-based scenes without adding a type
# parameter to SceneGeometry.
function SceneGeometry(
    mtg::MTG,
    merged_mesh::Mesh,
    face2node::Vector{Int},
    nodes::Dict{Int,SceneNodeData{T}},
    source_path::String,
    scene_xy_bounds::Union{Nothing,NTuple{4,T}},
) where {MTG,Mesh,T}
    return SceneGeometry(
        mtg,
        merged_mesh,
        face2node,
        nodes,
        source_path,
        scene_xy_bounds,
        SceneUnits(),
    )
end

function SceneGeometry{MTG,Mesh,T}(
    mtg::MTG,
    merged_mesh::Mesh,
    face2node::Vector{Int},
    nodes::Dict{Int,SceneNodeData{T}},
    source_path::String,
    scene_xy_bounds::Union{Nothing,NTuple{4,T}},
) where {MTG,Mesh,T}
    return SceneGeometry{MTG,Mesh,T}(
        mtg,
        merged_mesh,
        face2node,
        nodes,
        source_path,
        scene_xy_bounds,
        SceneUnits(),
    )
end

"""
    scene_version(scene::SceneGeometry) -> Int

Return the version counter stored on the exact MTG root backing `scene`.
"""
scene_version(scene::SceneGeometry) = scene_version(scene.mtg)

"""
    SceneBuilder

Mutable builder passed to [`make_scene`](@ref) callback blocks.

Users normally do not construct `SceneBuilder` directly. Instead, use:

```julia
scene = make_scene(domain=(0.0, 0.0, 10.0, 5.0)) do builder
    add_plant!(builder, plant; group="plants", id=1)
    add_ground!(builder)
end
```

Fields:

- `mtg`: scene root being assembled.
- `domain`: scene XY domain as `(xmin, ymin, xmax, ymax)`.
- `source_path`: provenance label forwarded to [`SceneGeometry`](@ref).
- `compute_area`: whether prepared node summaries should include surface area.
- `compute_barycenter`: whether summaries should include area-weighted
  barycenters.
- `source_topology_id`: whether summaries should preserve source topology ids.
- `next_node_id`: next scene-level MTG node id used during insertion.
- `next_source_instance_id`: next deterministic namespace used for an object
  inserted through this builder.
- `units`: metadata describing the physical length unit of the scene.
"""
mutable struct SceneBuilder
    mtg
    domain::Union{Nothing,NTuple{4,Float64}}
    source_path::String
    compute_area::Bool
    compute_barycenter::Bool
    source_topology_id::Bool
    next_node_id::Int
    next_source_instance_id::Int
    units::SceneUnits
end

function _next_scene_source_instance_id(mtg)
    maximum_instance_id = Ref(0)
    MultiScaleTreeGraph.traverse!(mtg) do node
        instance_id = _scene_positive_int_attribute(
            node,
            _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
        )
        instance_id === nothing ||
            (maximum_instance_id[] = max(maximum_instance_id[], instance_id))
        ownership = _stored_source_ownership(node)
        ownership === nothing ||
            (maximum_instance_id[] = max(
                maximum_instance_id[],
                ownership.source_instance_id,
            ))
    end
    maximum_instance_id[] == typemax(Int) && throw(
        OverflowError("Cannot allocate another scene source-instance id."),
    )
    return maximum_instance_id[] + 1
end

SceneBuilder(
    mtg,
    domain::Union{Nothing,NTuple{4,Float64}},
    source_path::String,
    compute_area::Bool,
    compute_barycenter::Bool,
    source_topology_id::Bool,
) = SceneBuilder(
    mtg,
    domain,
    source_path,
    compute_area,
    compute_barycenter,
    source_topology_id,
    MultiScaleTreeGraph.max_id(mtg) + 1,
    _next_scene_source_instance_id(mtg),
    SceneUnits(),
)

SceneBuilder(
    mtg,
    domain::Union{Nothing,NTuple{4,Float64}},
    source_path::String,
    compute_area::Bool,
    compute_barycenter::Bool,
    source_topology_id::Bool,
    units::SceneUnits,
) = SceneBuilder(
    mtg,
    domain,
    source_path,
    compute_area,
    compute_barycenter,
    source_topology_id,
    MultiScaleTreeGraph.max_id(mtg) + 1,
    _next_scene_source_instance_id(mtg),
    units,
)

SceneBuilder(
    mtg,
    domain::Union{Nothing,NTuple{4,Float64}},
    source_path::String,
    compute_area::Bool,
    compute_barycenter::Bool,
    source_topology_id::Bool,
    next_node_id::Int,
) = SceneBuilder(
    mtg,
    domain,
    source_path,
    compute_area,
    compute_barycenter,
    source_topology_id,
    next_node_id,
    _next_scene_source_instance_id(mtg),
    SceneUnits(),
)

SceneBuilder(
    mtg,
    domain::Union{Nothing,NTuple{4,Float64}},
    source_path::String,
    compute_area::Bool,
    compute_barycenter::Bool,
    source_topology_id::Bool,
    next_node_id::Int,
    units::SceneUnits,
) = SceneBuilder(
    mtg,
    domain,
    source_path,
    compute_area,
    compute_barycenter,
    source_topology_id,
    next_node_id,
    _next_scene_source_instance_id(mtg),
    units,
)

SceneBuilder(
    mtg,
    domain::Union{Nothing,NTuple{4,Float64}},
    source_path::String,
    compute_area::Bool,
    compute_barycenter::Bool,
    source_topology_id::Bool,
    next_node_id::Int,
    next_source_instance_id::Int,
) = SceneBuilder(
    mtg,
    domain,
    source_path,
    compute_area,
    compute_barycenter,
    source_topology_id,
    next_node_id,
    next_source_instance_id,
    SceneUnits(),
)

scene_length_unit(scene::SceneGeometry) = scene_length_unit(scene.units)
scene_length_unit(builder::SceneBuilder) = scene_length_unit(builder.units)
scene_area_unit(scene::SceneGeometry) = scene_area_unit(scene.units)
scene_area_unit(builder::SceneBuilder) = scene_area_unit(builder.units)

"""
    scene_node(scene::SceneGeometry, node_id)

Return the [`SceneNodeData`](@ref) summary for `node_id`, or `nothing` if that
node has no prepared geometry summary.
"""
scene_node(scene::SceneGeometry, node_id::Integer) = get(scene.nodes, Int(node_id), nothing)

"""
    scene_node_ids(scene::SceneGeometry)

Return the sorted MTG node ids present in the prepared scene summaries.

These are the ids used in `scene.face2node`, [`scene_node`](@ref),
[`node_areas`](@ref), and [`node_barycenters`](@ref).
"""
scene_node_ids(scene::SceneGeometry) = sort!(collect(keys(scene.nodes)))

"""
    source_owner(scene::SceneGeometry, node_id)

Return the opaque [`SourceOwnerKey`](@ref) associated with one scene MTG node,
or `nothing` when the node has no prepared geometry summary or ownership.
"""
function source_owner(scene::SceneGeometry, node_id::Integer)
    node = scene_node(scene, node_id)
    node === nothing ? nothing : node.source_owner
end

"""
    source_owners(scene::SceneGeometry)

Return a dictionary from prepared scene MTG node ids to their opaque botanical
source-owner keys. The dictionary is independent of mesh-face order.
"""
source_owners(scene::SceneGeometry) =
    Dict(nid => node.source_owner for (nid, node) in scene.nodes)

"""
    compile_source_owner_map(scene, runtime; owner_keys=nothing,
                             source_roots=nothing, object_resolver=nothing)

Compile the opaque [`SourceOwnerKey`](@ref) values present in `scene` to the
stable object identities owned by an optional simulation runtime.

PlantGeom core deliberately does not depend on a simulation engine. A concrete
method is provided by the PlantSimEngine package extension when PlantSimEngine
is loaded.
"""
function compile_source_owner_map end

"""
    source_owner_map_iscurrent(map[, scene, runtime])

Return whether a compiled source-owner map still describes the same scene and
simulation topology. The concrete method is supplied by the simulation-engine
extension that created `map`.
"""
function source_owner_map_iscurrent end

"""
    node_areas(scene::SceneGeometry)

Return a dictionary mapping each prepared MTG node id to its surface area.

Values are `nothing` when the scene was prepared with `compute_area=false`.
"""
node_areas(scene::SceneGeometry) = Dict(nid => node.area for (nid, node) in scene.nodes)

"""
    node_barycenters(scene::SceneGeometry)

Return a dictionary mapping each prepared MTG node id to its area-weighted
barycenter `(x, y, z)`.

Values are `nothing` when the scene was prepared with
`compute_barycenter=false`. Degenerate zero-area nodes receive `(NaN, NaN, NaN)`
when barycenter computation is enabled.
"""
node_barycenters(scene::SceneGeometry) = Dict(nid => node.barycenter for (nid, node) in scene.nodes)

function _coerce_scene_domain(domain)
    domain === nothing && return nothing
    length(domain) == 4 || error("Scene domain must be a 4-tuple `(xmin, ymin, xmax, ymax)`.")
    vals = ntuple(i -> Float64(domain[i]), 4)
    vals[3] > vals[1] || error("Scene domain must satisfy xmax > xmin.")
    vals[4] > vals[2] || error("Scene domain must satisfy ymax > ymin.")
    return vals
end

function _set_scene_dimensions!(mtg, bounds::NTuple{4,Float64})
    xmin, ymin, xmax, ymax = bounds
    mtg[:scene_dimensions] = (
        GeometryBasics.Point3f(Float32(xmin), Float32(ymin), 0.0f0),
        GeometryBasics.Point3f(Float32(xmax), Float32(ymax), 0.0f0),
    )
    return mtg
end

function _scene_root(
    domain::Union{Nothing,NTuple{4,Float64}};
    mtg_type=MultiScaleTreeGraph.NodeMTG,
)
    root = MultiScaleTreeGraph.Node(
        mtg_type(:/, :Scene, 1, 0),
        Dict{Symbol,Any}(),
    )
    domain === nothing || _set_scene_dimensions!(root, domain)
    return root
end

@inline function _is_scene_geometry_node(node)
    has_geometry(node) || return false
    !haskey(node, :scene_dimensions)
end

function _scene_xy_bounds_from_mtg(mtg)
    haskey(mtg, :scene_dimensions) || return nothing
    dims = mtg[:scene_dimensions]
    dims === nothing && return nothing
    if dims isa AbstractString
        matches = collect(eachmatch(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", dims))
        length(matches) >= 5 || return nothing
        values = parse.(Float64, getfield.(matches, :match))
        return (
            min(values[1], values[4]),
            min(values[2], values[5]),
            max(values[1], values[4]),
            max(values[2], values[5]),
        )
    end
    p0 = dims[1]
    p1 = dims[2]
    return (
        min(Float64(p0[1]), Float64(p1[1])),
        min(Float64(p0[2]), Float64(p1[2])),
        max(Float64(p0[1]), Float64(p1[1])),
        max(Float64(p0[2]), Float64(p1[2])),
    )
end

function _scene_triangle_area3d(p1, p2, p3)
    v1 = StaticArrays.SVector{3,Float64}(p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3])
    v2 = StaticArrays.SVector{3,Float64}(p3[1] - p1[1], p3[2] - p1[2], p3[3] - p1[3])
    0.5 * norm(cross(v1, v2))
end

function _source_topology_id(node)
    haskey(node, :source_topology_id) || return nothing
    v = node[:source_topology_id]
    (v === nothing || ismissing(v)) && return nothing
    try
        id = Int(v)
        id > 0 && return id
    catch
    end
    return nothing
end

function _scene_positive_int_attribute(node, key::Symbol)
    haskey(node, key) || return nothing
    value = node[key]
    (value === nothing || ismissing(value)) && return nothing
    try
        parsed = Int(value)
        parsed > 0 && return parsed
    catch
    end
    return nothing
end

function _source_object_root(node)
    current = node
    while true
        _scene_positive_int_attribute(
            current,
            _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
        ) === nothing || return current
        MultiScaleTreeGraph.isroot(current) && return current
        current = MultiScaleTreeGraph.parent(current)
    end
end

@inline _coerce_scene_source_ownership(::Nothing, _) = nothing
@inline _coerce_scene_source_ownership(::Missing, _) = nothing
@inline _coerce_scene_source_ownership(
    ownership::_SceneSourceOwnership,
    _,
) = ownership
@noinline function _coerce_scene_source_ownership(ownership, node)
    throw(ArgumentError(
        "Private scene ownership metadata must contain a _SceneSourceOwnership; " *
        "got $(typeof(ownership)) on node $(MultiScaleTreeGraph.node_id(node)).",
    ))
end

# MultiScaleTreeGraph's generic `get(::ColumnarAttrs, ...)` has an `Any`
# fallback, which boxes one ownership value per node even when its column has a
# concrete type. Keep the hot path typed until the dependency exposes a public
# typed attribute accessor. These internals are available throughout our
# supported MultiScaleTreeGraph 0.15 series.
@inline function _columnar_source_ownership(
    attrs::MultiScaleTreeGraph.ColumnarAttrs,
    node,
)::Union{Nothing,_SceneSourceOwnership}
    if !MultiScaleTreeGraph._isbound(attrs)
        return _coerce_scene_source_ownership(
            get(attrs.staged, _SCENE_SOURCE_OWNERSHIP_ATTRIBUTE, nothing),
            node,
        )
    end

    store, bucket_id, row = MultiScaleTreeGraph._bound_store_bid_row(attrs.ref)
    bucket = store.buckets[bucket_id]
    column_index = get(bucket.col_index, _SCENE_SOURCE_OWNERSHIP_ATTRIBUTE, 0)
    column_index == 0 && return nothing

    if MultiScaleTreeGraph._column_matches_exact_type(
        bucket,
        column_index,
        _SceneSourceOwnership,
    )
        column = bucket.columns[column_index]::MultiScaleTreeGraph.Column{_SceneSourceOwnership}
        return @inbounds column.data[row]
    elseif MultiScaleTreeGraph._column_matches_nullable_type(
        bucket,
        column_index,
        _SceneSourceOwnership,
    )
        column = bucket.columns[column_index]::MultiScaleTreeGraph.Column{Union{Nothing,_SceneSourceOwnership}}
        return @inbounds column.data[row]
    end

    return _coerce_scene_source_ownership(
        MultiScaleTreeGraph._get_value(
            bucket,
            row,
            _SCENE_SOURCE_OWNERSHIP_ATTRIBUTE,
            nothing,
        ),
        node,
    )
end

@inline function _stored_source_ownership(node)
    ownership = _columnar_source_ownership(
        MultiScaleTreeGraph.node_attributes(node),
        node,
    )
    ownership === nothing && return nothing
    ownership.source_instance_id > 0 &&
        ownership.source_node_id > 0 &&
        ownership.owner_node_id > 0 || throw(ArgumentError(
        "Private scene ownership metadata must contain positive ids; got " *
        "$ownership on node $(MultiScaleTreeGraph.node_id(node)).",
    ))
    return ownership
end

@inline function _stored_source_owner_key(node)
    ownership = _stored_source_ownership(node)
    ownership === nothing && return nothing
    return SourceOwnerKey(ownership.source_instance_id, ownership.owner_node_id)
end

@inline function _root_source_owner_resolver(root)
    haskey(root, _SCENE_SOURCE_OWNER_RESOLVER_ATTRIBUTE) || return nothing
    resolver = root[_SCENE_SOURCE_OWNER_RESOLVER_ATTRIBUTE]
    return resolver === nothing || ismissing(resolver) ? nothing : resolver
end

@inline function _default_source_owner_node_id(node)
    return something(_source_topology_id(node), MultiScaleTreeGraph.node_id(node))
end

@inline function _intrinsic_source_node_id(node)
    ownership = _stored_source_ownership(node)
    return ownership === nothing ?
           _default_source_owner_node_id(node) : ownership.source_node_id
end

@inline function _set_source_ownership!(
    node,
    source_instance_id::Int,
    source_node_id::Int,
    owner_node_id::Int,
)
    ownership = _SceneSourceOwnership(
        source_instance_id,
        source_node_id,
        owner_node_id,
    )
    node[_SCENE_SOURCE_OWNERSHIP_ATTRIBUTE] = ownership
    return ownership
end

@inline function _rebase_node_source_ownership!(node, source_instance_id::Int)
    ownership = _stored_source_ownership(node)
    ownership === nothing && return nothing
    return _set_source_ownership!(
        node,
        source_instance_id,
        ownership.source_node_id,
        ownership.owner_node_id,
    )
end

function _resolve_source_owner(node, resolver)
    resolver === nothing && return (_default_source_owner_node_id(node), nothing)
    applicable(resolver, node) || throw(ArgumentError(
        "`source_owner` must be callable with an MTG node; got $(typeof(resolver)).",
    ))

    owner = resolver(node)
    owner_id = if owner isa MultiScaleTreeGraph.Node
        _source_object_root(owner) === _source_object_root(node) || throw(ArgumentError(
            "`source_owner` returned a node from another scene object for node " *
            "$(MultiScaleTreeGraph.node_id(node)). Owners must belong to the same object root.",
        ))
        _intrinsic_source_node_id(owner)
    elseif owner isa Integer
        Int(owner)
    else
        throw(ArgumentError(
            "`source_owner` must return an MTG node or integer source node id; " *
            "got $(typeof(owner)) for scene node $(MultiScaleTreeGraph.node_id(node)).",
        ))
    end
    owner_id > 0 || throw(ArgumentError(
        "`source_owner` returned non-positive source node id $owner_id for " *
        "scene node $(MultiScaleTreeGraph.node_id(node)).",
    ))
    return owner_id, owner isa MultiScaleTreeGraph.Node ? owner : nothing
end

function _source_owner_node_id(
    node,
    resolver;
    source_instance_id::Union{Nothing,Int}=nothing,
    allow_owner_rebase::Bool=false,
)
    owner_id, owner = _resolve_source_owner(node, resolver)

    if source_instance_id !== nothing && owner !== nothing
        owner_ownership = _stored_source_ownership(owner)
        if owner_ownership === nothing
            _set_source_ownership!(
                owner,
                source_instance_id,
                owner_id,
                owner_id,
            )
        elseif owner_ownership.source_instance_id != source_instance_id
            allow_owner_rebase || throw(ArgumentError(
                "`source_owner` returned owner node " *
                "$(MultiScaleTreeGraph.node_id(owner)) from source instance " *
                "$(owner_ownership.source_instance_id), but node " *
                "$(MultiScaleTreeGraph.node_id(node)) belongs to source instance " *
                "$source_instance_id. Cross-instance owner anchors are unsupported.",
            ))
            _rebase_node_source_ownership!(owner, source_instance_id)
        end
    end
    return owner_id
end

@inline function _scene_source_roots(mtg)
    if MultiScaleTreeGraph.symbol(mtg) === :Scene
        has_geometry(mtg) && throw(ArgumentError(
            "A :Scene node is a container and cannot carry geometry directly. " *
            "Attach the geometry to an object node below the scene root.",
        ))
        return MultiScaleTreeGraph.children(mtg)
    end
    return (mtg,)
end

function _plan_rebased_source_ownership(
    root,
    old_source_instance_id::Int,
    source_instance_id::Int,
)
    resolver = _root_source_owner_resolver(root)
    nodes = typeof(root)[]
    MultiScaleTreeGraph.traverse!(root) do node
        push!(nodes, node)
        return nothing
    end

    node_indices = IdDict{typeof(root),Int}()
    existing_ownership = Vector{Union{Nothing,_SceneSourceOwnership}}(undef, length(nodes))
    planned_ownership = Vector{Union{Nothing,_SceneSourceOwnership}}(undef, length(nodes))
    fill!(planned_ownership, nothing)
    @inbounds for index in eachindex(nodes)
        node = nodes[index]
        node_indices[node] = index
        ownership = _stored_source_ownership(node)
        existing_ownership[index] = ownership
        if ownership !== nothing
            _validate_geometry_source_instance(
                node,
                ownership,
                old_source_instance_id,
            )
            planned_ownership[index] = _SceneSourceOwnership(
                source_instance_id,
                ownership.source_node_id,
                ownership.owner_node_id,
            )
        end
    end

    owner_indices = Int[]
    @inbounds for index in eachindex(nodes)
        existing_ownership[index] === nothing || continue
        node = nodes[index]
        if _is_scene_geometry_node(node)
            source_node_id = _default_source_owner_node_id(node)
            owner_id, owner = _resolve_source_owner(node, resolver)
            planned_ownership[index] = _SceneSourceOwnership(
                source_instance_id,
                source_node_id,
                owner_id,
            )
            if owner !== nothing
                owner_index = get(node_indices, owner, 0)
                owner_index > 0 || error(
                    "Resolved source owner is missing from its object traversal.",
                )
                push!(owner_indices, owner_index)
            end
        end
    end

    # A non-geometric owner anchor needs its own intrinsic identity retained.
    # Geometry owners already have their resolver-derived plan, while existing
    # stamps were rebased in the first pass.
    for owner_index in owner_indices
        planned_ownership[owner_index] === nothing || continue
        owner = nodes[owner_index]
        owner_source_node_id = _default_source_owner_node_id(owner)
        planned_ownership[owner_index] = _SceneSourceOwnership(
            source_instance_id,
            owner_source_node_id,
            owner_source_node_id,
        )
    end
    return nodes, planned_ownership
end

function _rebase_source_ownership!(root, source_instance_id::Int)
    source_instance_id > 0 || throw(ArgumentError(
        "Scene source-instance ids must be positive; got $source_instance_id.",
    ))
    old_source_instance_id = _scene_positive_int_attribute(
        root,
        _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
    )
    old_source_instance_id === nothing && throw(ArgumentError(
        "Cannot rebase source ownership without an existing positive " *
        "source-instance namespace on the object root.",
    ))
    nodes, planned_ownership = _plan_rebased_source_ownership(
        root,
        old_source_instance_id,
        source_instance_id,
    )

    # Commit only after every resolver result and existing stamp was validated.
    root[_SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE] = source_instance_id
    @inbounds for index in eachindex(nodes)
        ownership = planned_ownership[index]
        ownership === nothing ||
            (nodes[index][_SCENE_SOURCE_OWNERSHIP_ATTRIBUTE] = ownership)
    end
    return root
end

function _normalize_scene_source_instances!(mtg)
    roots = _scene_source_roots(mtg)
    newly_namespaced_roots = falses(length(roots))
    maximum_instance_id = 0
    allocations_required = 0
    seen_instances = Set{Int}()

    for root in roots
        instance_id = _scene_positive_int_attribute(
            root,
            _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
        )
        if instance_id === nothing || instance_id in seen_instances
            allocations_required += 1
        else
            maximum_instance_id = max(maximum_instance_id, instance_id)
            push!(seen_instances, instance_id)
        end
    end

    if allocations_required > 0 &&
       maximum_instance_id > typemax(Int) - allocations_required
        throw(OverflowError(
            "Cannot allocate $allocations_required additional scene " *
            "source-instance id(s) after $maximum_instance_id.",
        ))
    end
    next_instance_id = allocations_required > 0 ? maximum_instance_id + 1 : 0
    empty!(seen_instances)

    for (root_index, root) in enumerate(roots)
        instance_id = _scene_positive_int_attribute(
            root,
            _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
        )
        if instance_id === nothing
            instance_id = next_instance_id
            root[_SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE] = instance_id
            newly_namespaced_roots[root_index] = true
            allocations_required -= 1
            allocations_required > 0 && (next_instance_id += 1)
        elseif instance_id in seen_instances
            instance_id = next_instance_id
            _rebase_source_ownership!(root, instance_id)
            allocations_required -= 1
            allocations_required > 0 && (next_instance_id += 1)
        end
        push!(seen_instances, instance_id)
    end
    return roots, newly_namespaced_roots
end

@inline function _validate_geometry_source_instance(
    node,
    ownership::_SceneSourceOwnership,
    source_instance_id::Int,
)
    ownership.source_instance_id == source_instance_id || throw(ArgumentError(
        "Scene node $(MultiScaleTreeGraph.node_id(node)) was reparented across " *
        "source instances ($(ownership.source_instance_id) => $source_instance_id). " *
        "Cross-instance reparenting is unsupported because it would change source identity.",
    ))
    return nothing
end

function _validate_geometry_source_instance(node, source_instance_id::Int)
    ownership = _stored_source_ownership(node)
    ownership === nothing && return nothing
    return _validate_geometry_source_instance(node, ownership, source_instance_id)
end

@inline function _compiled_scene_ownership(
    node,
    source_instance_id::Int,
    source_root_index::Int,
    ownership::Union{Nothing,_SceneSourceOwnership},
    source_owner_resolver,
)
    if ownership === nothing
        source_node_id = _default_source_owner_node_id(node)
        return _CompiledSceneOwnership(
            source_instance_id,
            source_node_id,
            source_owner_resolver === nothing ? -source_node_id : 0,
            source_root_index,
        )
    end
    return _CompiledSceneOwnership(
        ownership.source_instance_id,
        ownership.source_node_id,
        ownership.owner_node_id,
        source_root_index,
    )
end

@inline function _preflight_scene_ownership(
    node,
    source_instance_id::Int,
    source_namespace_was_missing::Bool,
)
    ownership = _stored_source_ownership(node)
    ownership === nothing && return nothing
    source_namespace_was_missing && throw(ArgumentError(
        "A source root contains ownership stamps but no source-instance namespace. " *
        "Reinsert the complete stamped object instead of discarding its private " *
        "root metadata.",
    ))
    _validate_geometry_source_instance(node, ownership, source_instance_id)
    return ownership
end


function _validate_geometry_source_instance(node)
    object_root = _source_object_root(node)
    source_instance_id = _scene_positive_int_attribute(
        object_root,
        _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
    )
    source_instance_id === nothing && error(
        "Scene source namespaces must be normalized before resolving ownership.",
    )
    return _validate_geometry_source_instance(node, source_instance_id)
end

@inline function _source_owner_key_from_compiled!(
    node,
    ownership::_CompiledSceneOwnership,
    source_roots,
)
    if ownership.owner_node_id > 0
        return SourceOwnerKey(
            ownership.source_instance_id,
            ownership.owner_node_id,
        )
    elseif ownership.owner_node_id < 0
        owner_node_id = -ownership.owner_node_id
        _set_source_ownership!(
            node,
            ownership.source_instance_id,
            ownership.source_node_id,
            owner_node_id,
        )
        return SourceOwnerKey(ownership.source_instance_id, owner_node_id)
    end

    object_root = source_roots[ownership.source_root_index]
    root_source_instance_id = _scene_positive_int_attribute(
        object_root,
        _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
    )
    root_source_instance_id === nothing && error(
        "Scene source namespaces must be normalized before resolving ownership.",
    )
    ownership.source_instance_id == root_source_instance_id || error(
        "Compiled scene source metadata no longer matches the MTG topology.",
    )
    owner_id = _source_owner_node_id(
        node,
        _root_source_owner_resolver(object_root);
        source_instance_id=ownership.source_instance_id,
    )
    _set_source_ownership!(
        node,
        ownership.source_instance_id,
        ownership.source_node_id,
        owner_id,
    )
    return SourceOwnerKey(ownership.source_instance_id, owner_id)
end

function _ensure_source_ownership_before_relabel!(roots, newly_namespaced_roots)
    # Validate every existing stamp before either stamping new geometry or
    # changing any node id. This includes non-geometric botanical owner anchors.
    for (root_index, root) in enumerate(roots)
        source_instance_id = _scene_positive_int_attribute(
            root,
            _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
        )
        MultiScaleTreeGraph.traverse!(root) do node
            ownership = _stored_source_ownership(node)
            ownership === nothing && return nothing
            newly_namespaced_roots[root_index] && throw(ArgumentError(
                "A source root contains ownership stamps but no source-instance " *
                "namespace. Reinsert the complete stamped object instead of " *
                "discarding its private root metadata.",
            ))
            _validate_geometry_source_instance(
                node,
                ownership,
                source_instance_id,
            )
            return nothing
        end
    end

    for root in roots
        source_instance_id = _scene_positive_int_attribute(
            root,
            _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
        )
        resolver = _root_source_owner_resolver(root)
        MultiScaleTreeGraph.traverse!(root, filter_fun=_is_scene_geometry_node) do node
            ownership = _stored_source_ownership(node)
            if ownership === nothing
                source_node_id = _default_source_owner_node_id(node)
                owner_id = _source_owner_node_id(
                    node,
                    resolver;
                    source_instance_id=source_instance_id,
                )
                _set_source_ownership!(
                    node,
                    source_instance_id,
                    source_node_id,
                    owner_id,
                )
            elseif ownership.source_instance_id != source_instance_id
                _validate_geometry_source_instance(node)
            end
            return nothing
        end
    end
    return nothing
end

function _populate_scene_node_summaries!(
    nodes,
    geometry_node_ids,
    geometry_nelems,
    geometry_nodes,
    geometry_ownership,
    geometry_seqs,
    node_area,
    bary_acc,
    source_roots,
    ::Val{COMPUTE_AREA},
    ::Val{COMPUTE_BARYCENTER},
    ::Val{SOURCE_TOPOLOGY_ID},
) where {COMPUTE_AREA,COMPUTE_BARYCENTER,SOURCE_TOPOLOGY_ID}
    @inbounds for i in eachindex(geometry_node_ids)
        geometry_nelems[i] > 0 || continue
        nid = geometry_node_ids[i]
        geometry_seq = geometry_seqs[i]
        node = geometry_nodes[geometry_seq]
        area = COMPUTE_AREA ? get(node_area, nid, 0.0) : nothing
        barycenter = if COMPUTE_BARYCENTER
            denom = get(node_area, nid, 0.0)
            if denom > 0
                sx, sy, sz = get(bary_acc, nid, (0.0, 0.0, 0.0))
                (sx / denom, sy / denom, sz / denom)
            else
                (NaN, NaN, NaN)
            end
        else
            nothing
        end
        sid = if SOURCE_TOPOLOGY_ID
            something(_source_topology_id(node), nid)
        else
            nothing
        end
        owner = _source_owner_key_from_compiled!(
            node,
            geometry_ownership[geometry_seq],
            source_roots,
        )
        nodes[nid] = SceneNodeData{Float64}(area, barycenter, sid, owner)
    end
    return nodes
end

"""
    prepare_scene(mtg; source_path="interactive.scene", domain=nothing,
                  scene_xy_bounds=nothing, relabel_ids=false,
                  compute_area=true, compute_barycenter=true,
                  source_topology_id=true, units=SceneUnits())

Prepare an MTG scene root for geometry-level downstream work.

`prepare_scene` expects an MTG whose geometry-bearing descendants already live
in scene coordinates. It merges all geometry nodes into one mesh and builds a
face-to-node map so every face in the merged mesh can be traced back to the MTG
node that produced it.

Keyword arguments:

- `source_path`: provenance label stored on the returned [`SceneGeometry`](@ref).
- `domain`: explicit scene XY domain `(xmin, ymin, xmax, ymax)`. When provided,
  it takes precedence over `scene_xy_bounds` and over `mtg[:scene_dimensions]`.
- `scene_xy_bounds`: fallback scene XY domain `(xmin, ymin, xmax, ymax)`.
- `relabel_ids`: when `true`, relabel MTG node ids before merging. This is
  useful after assembling independent object roots that may have overlapping
  ids.
- `compute_area`: compute total triangle area per MTG node.
- `compute_barycenter`: compute area-weighted barycenter per MTG node.
- `source_topology_id`: preserve original topology ids in node summaries when
  nodes carry a `:source_topology_id` attribute.
- `units`: metadata describing the physical unit of the existing numeric
  coordinates. `prepare_scene` never rescales geometry.

The function records private `_scene_*` ownership metadata on object roots and
geometry nodes so ownership remains stable across refreshes and organogenesis.
It also mutates `mtg` when `relabel_ids=true` or when a domain is written back
as `mtg[:scene_dimensions]`. Private scene metadata is omitted by OPF writers.
The function returns a [`SceneGeometry`](@ref).

Use [`make_scene`](@ref) for new scene construction; use `prepare_scene`
directly when you already have a scene MTG.
"""
function prepare_scene(
    mtg;
    source_path::AbstractString="interactive.scene",
    domain=nothing,
    scene_xy_bounds=nothing,
    relabel_ids::Bool=false,
    compute_area::Bool=true,
    compute_barycenter::Bool=true,
    source_topology_id::Bool=true,
    units::SceneUnits=SceneUnits(),
)
    source_roots, newly_namespaced_roots = _normalize_scene_source_instances!(mtg)
    if relabel_ids
        # Establish fallback owner ids while they still refer to the source
        # topology. Subsequent relabelling may change scene node ids, never the
        # already-established botanical owner keys.
        _ensure_source_ownership_before_relabel!(
            source_roots,
            newly_namespaced_roots,
        )
        fill!(newly_namespaced_roots, false)
        _relabel_node_ids!(mtg, Ref(1))
    end
    bounds = domain === nothing ? scene_xy_bounds : domain
    bounds = bounds === nothing ? _scene_xy_bounds_from_mtg(mtg) : _coerce_scene_domain(bounds)
    bounds === nothing || _set_scene_dimensions!(mtg, bounds)

    merged_mesh,
    face2node,
    geometry_node_ids,
    geometry_nelems,
    geometry_nodes,
    geometry_ownership,
    geometry_seqs =
        _build_merged_mesh_with_map(
            Val(true),
            mtg;
            filter_fun=_is_scene_geometry_node,
            source_roots=source_roots,
            newly_namespaced_roots=newly_namespaced_roots,
        )
    nodes = Dict{Int,SceneNodeData{Float64}}()
    sizehint!(nodes, length(geometry_node_ids))

    node_area = Dict{Int,Float64}()
    bary_acc = Dict{Int,NTuple{3,Float64}}()
    if compute_area || compute_barycenter
        sizehint!(node_area, length(geometry_node_ids))
        compute_barycenter && sizehint!(bary_acc, length(geometry_node_ids))
        verts = GeometryBasics.decompose(GeometryBasics.Point3, merged_mesh)
        faces = GeometryBasics.decompose(Face3, merged_mesh)
        for (i, f) in enumerate(faces)
            nid = face2node[i]
            p1 = verts[f[1]]
            p2 = verts[f[2]]
            p3 = verts[f[3]]
            area = _scene_triangle_area3d(p1, p2, p3)
            (compute_area || compute_barycenter) && (node_area[nid] = get(node_area, nid, 0.0) + area)
            if compute_barycenter
                cx = (p1[1] + p2[1] + p3[1]) / 3.0
                cy = (p1[2] + p2[2] + p3[2]) / 3.0
                cz = (p1[3] + p2[3] + p3[3]) / 3.0
                sx, sy, sz = get(bary_acc, nid, (0.0, 0.0, 0.0))
                bary_acc[nid] = (sx + area * cx, sy + area * cy, sz + area * cz)
            end
        end
    end

    _populate_scene_node_summaries!(
        nodes,
        geometry_node_ids,
        geometry_nelems,
        geometry_nodes,
        geometry_ownership,
        geometry_seqs,
        node_area,
        bary_acc,
        source_roots,
        Val(compute_area),
        Val(compute_barycenter),
        Val(source_topology_id),
    )

    return SceneGeometry(
        mtg,
        merged_mesh,
        face2node,
        nodes,
        String(source_path),
        bounds,
        units,
    )
end

function _refresh_scene!(scene::SceneGeometry; compute_area::Bool=true, compute_barycenter::Bool=true, source_topology_id::Bool=true)
    scene.mtg === nothing && error("Scene refresh requires an MTG-backed scene.")
    bump_scene_version!(scene.mtg)
    refreshed = prepare_scene(
        scene.mtg;
        source_path=scene.source_path,
        scene_xy_bounds=scene.scene_xy_bounds,
        relabel_ids=false,
        compute_area=compute_area,
        compute_barycenter=compute_barycenter,
        source_topology_id=source_topology_id,
        units=scene.units,
    )
    scene.merged_mesh = refreshed.merged_mesh
    scene.face2node = refreshed.face2node
    scene.nodes = refreshed.nodes
    scene.scene_xy_bounds = refreshed.scene_xy_bounds
    scene.units = refreshed.units
    return scene
end

function _mesh_object_mtg(mesh; type::AbstractString, name::AbstractString="object")
    root = MultiScaleTreeGraph.Node(
        MultiScaleTreeGraph.NodeMTG(:/, :Object, 1, 1),
        Dict{Symbol,Any}(),
    )
    MultiScaleTreeGraph.Node(
        2,
        root,
        MultiScaleTreeGraph.NodeMTG(:+, Symbol(type), 2, 2),
        Dict{Symbol,Any}(
            :geometry => Geometry(ref_mesh=RefMesh(String(name), mesh)),
            :type => String(type),
        ),
    )
    return root
end

function _read_scene_object(
    path::AbstractString;
    type::AbstractString="object",
    mtg_type=MultiScaleTreeGraph.MutableNodeMTG,
)
    ext = lowercase(splitext(path)[2])
    ext == ".opf" && return read_opf(
        path,
        attr_type=Dict,
        mtg_type=mtg_type,
        attribute_types=Dict("pos" => Float64),
    )
    ext == ".gwa" && return read_gwa(path; mtg_type=mtg_type)
    error("add_object! accepts `.opf` and `.gwa` paths directly. For mesh files such as `.obj` or `.ply`, load them with MeshIO/FileIO first, then pass the mesh to add_object!. Use read_ops for `.ops` scenes.")
end

function _set_node_attrs!(node; attrs...)
    for (k, v) in attrs
        node[Symbol(k)] = v
    end
    return node
end

function _annotate_object_root!(root; group::AbstractString, id::Integer, file_path::AbstractString="", attrs...)
    root[:group] = String(group)
    root[:functional_group] = String(group)
    root[:id] = Int(id)
    root[:object_id] = Int(id)
    root[:plantID] = Int(id)
    isempty(file_path) || (root[:filePath] = String(file_path))
    _set_node_attrs!(root; attrs...)
    return root
end

function _ops_rotation_metadata(rotate, deg::Bool)
    rotation = 0.0
    for (axis, angle) in _manual_rotation_sequence(rotate)
        angle == 0.0 && continue
        axis === :z || return nothing
        rotation = _manual_angle_rad(angle, deg)
    end
    return rotation
end

function _store_ops_placement_metadata!(
    root,
    scene_transformation;
    at,
    scale,
    rotate,
    deg::Bool,
    rotation,
    inclination_azimut,
    inclination_angle,
    transform,
)
    transform === nothing || return root
    scale isa Real || return root

    rotation_val = if rotation === nothing
        _ops_rotation_metadata(rotate, deg)
    else
        _manual_angle_rad(rotation, deg)
    end
    rotation_val === nothing && return root

    root[:pos] = _scene_point3(at)
    root[:scale] = Float64(scale)
    root[:rotation] = rotation_val
    root[:inclinationAzimut] = deg ? deg2rad(Float64(inclination_azimut)) : Float64(inclination_azimut)
    root[:inclinationAngle] = deg ? deg2rad(Float64(inclination_angle)) : Float64(inclination_angle)
    root[:scene_transformation] = scene_transformation
    return root
end

function _transform_object!(
    mtg,
    transformation;
    source_instance_id=nothing,
    source_owner=nothing,
)
    normalized_instance_id = source_instance_id === nothing ? 0 : Int(source_instance_id)
    resolver = if source_instance_id === nothing
        nothing
    elseif source_owner === nothing
        _root_source_owner_resolver(mtg)
    else
        source_owner
    end
    if source_instance_id !== nothing
        mtg[_SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE] = normalized_instance_id
        if source_owner !== nothing
            mtg[_SCENE_SOURCE_OWNER_RESOLVER_ATTRIBUTE] = source_owner
        end
    end
    MultiScaleTreeGraph.traverse!(mtg) do node
        node_has_geometry = has_geometry(node)
        if source_instance_id !== nothing
            existing_ownership = _stored_source_ownership(node)
            if node_has_geometry
                source_node_id = existing_ownership === nothing ?
                                 _default_source_owner_node_id(node) :
                                 existing_ownership.source_node_id
                owner_id = if source_owner === nothing && existing_ownership !== nothing
                    existing_ownership.owner_node_id
                elseif resolver === nothing
                    source_node_id
                else
                    _source_owner_node_id(
                        node,
                        resolver;
                        source_instance_id=normalized_instance_id,
                        allow_owner_rebase=true,
                    )
                end
                _set_source_ownership!(
                    node,
                    normalized_instance_id,
                    source_node_id,
                    owner_id,
                )
            elseif existing_ownership !== nothing
                _rebase_node_source_ownership!(node, normalized_instance_id)
            end
        end
        node_has_geometry && !(transformation isa IdentityTransformation) &&
            transform_mesh!(node, transformation)
        return nothing
    end
    return mtg
end

function _rotation_is_zero(rotate)
    return all(pair -> last(pair) == 0.0, _manual_rotation_sequence(rotate))
end

function _placement_transform(;
    at=(0.0, 0.0, 0.0),
    scale=1.0,
    rotate=(0.0, 0.0, 0.0),
    deg::Bool=false,
    rotation=nothing,
    inclination_azimut=0.0,
    inclination_angle=0.0,
    transform=nothing,
)
    if rotation !== nothing || inclination_azimut != 0.0 || inclination_angle != 0.0
        _rotation_is_zero(rotate) || error("Use either `rotate=` or OPS-style `rotation=`/`inclination_*=` placement, not both.")
        scale isa Real || error("OPS-style placement with `rotation=`/`inclination_*=` requires scalar `scale`.")
        ops = scene_object_transformation(
            ;
            at=at,
            scale=Float64(scale),
            rotation=rotation === nothing ? 0.0 : (deg ? deg2rad(Float64(rotation)) : Float64(rotation)),
            inclination_azimut=deg ? deg2rad(Float64(inclination_azimut)) : Float64(inclination_azimut),
            inclination_angle=deg ? deg2rad(Float64(inclination_angle)) : Float64(inclination_angle),
        )
        return transform === nothing ? ops : ops ∘ transform
    end
    p = pose(; scale=scale, rotate=rotate, at=at, deg=deg)
    return transform === nothing ? p : p ∘ transform
end

"""
    add_object!(builder::SceneBuilder, object; group, id, type="object",
                at=(0, 0, 0), scale=1.0, rotate=(0, 0, 0), deg=false,
                rotation=nothing, inclination_azimut=0.0,
                inclination_angle=0.0, transform=nothing,
                file_path="", source_owner=nothing,
                geometry_length_unit=nothing, kwargs...)
    add_object!(builder::SceneBuilder, path::AbstractString; type="object", kwargs...)

Add an object to a scene being assembled with [`make_scene`](@ref).

`object` can be:

- an MTG root containing geometry, such as an object read from `.opf` or `.gwa`
- a `GeometryBasics.AbstractMesh`, which is wrapped in a minimal object MTG

The path overload accepts `.opf` and `.gwa` files and reads them before adding
the object. It uses the same MTG encoding type as `builder.mtg`, so it works with
both `NodeMTG` and `MutableNodeMTG` scenes. For mesh formats such as `.obj` or
`.ply`, load the mesh yourself with a suitable IO package and pass the mesh
object directly.

Required metadata:

- `group`: semantic group name. Stored as both `:group` and
  `:functional_group`.
- `id`: object id. Stored as `:id`, `:object_id`, and `:plantID`.

Placement options:

- `at=(x, y, z)`: final translation.
- `scale=s` or `scale=(sx, sy, sz)`: uniform or anisotropic scaling for the
  simple transform path.
- `rotate=(x=..., y=..., z=...)` or `rotate=(rx, ry, rz)`: simple local-axis
  rotations used by [`pose`](@ref).
- `deg=true`: interpret `rotate`, `rotation`, `inclination_azimut`, and
  `inclination_angle` as degrees.
- `rotation`, `inclination_azimut`, `inclination_angle`: OPS-style scalar
  placement. These cannot be mixed with a nonzero `rotate=` value.
- `transform`: extra `CoordinateTransformations.Transformation` composed after
  the placement transform.
- `geometry_length_unit=nothing`: physical length unit of the input geometry.
  When supplied, coordinates are converted once to `builder.units` before
  placement. The default performs no conversion, which is appropriate for OPF
  inputs read with PlantGeom's default metre conversion when the scene is also
  in metres. Placement coordinates such as `at` are always expressed in the
  scene unit.
- `source_owner=nothing`: preserve any existing botanical owner mapping when
  re-instancing an already assembled object. A fresh scene-instance namespace
  is still assigned. For a first insertion, each geometry node owns itself.
- `source_owner=resolver`: explicitly recompute ownership before relabelling.
  The resolver receives each copied geometry node and returns its botanical
  owner node (or positive source node id). It is retained privately on the
  copied object root so geometry created later uses the same rule during
  [`prepare_scene`](@ref).

`add_object!` deep-copies MTG inputs before mutating them, annotates the object
root with placement metadata, applies the placement transform to all geometry
nodes, attaches the object under `builder.mtg`, and returns `builder`.

Extra keyword arguments are written as attributes on the copied object root.
All objects added to one builder must use the same MTG encoding type as the
scene root, for example `NodeMTG` with `NodeMTG`, or `MutableNodeMTG` with
`MutableNodeMTG`.
"""
function add_object!(
    builder::SceneBuilder,
    object;
    group::AbstractString,
    id::Integer,
    type::AbstractString="object",
    at=(0.0, 0.0, 0.0),
    scale=1.0,
    rotate=(0.0, 0.0, 0.0),
    deg::Bool=false,
    rotation=nothing,
    inclination_azimut=0.0,
    inclination_angle=0.0,
    transform=nothing,
    file_path::AbstractString="",
    source_owner=nothing,
    geometry_length_unit=nothing,
    kwargs...,
)
    0 < builder.next_source_instance_id < typemax(Int) || throw(OverflowError(
        "SceneBuilder has no remaining source-instance namespace.",
    ))
    unit_factor = _scene_length_conversion_factor(
        geometry_length_unit,
        builder.units,
    )
    obj = object isa GeometryBasics.AbstractMesh ? _mesh_object_mtg(object; type=type) : deepcopy(object)
    _annotate_object_root!(obj; group=group, id=id, file_path=file_path, kwargs...)
    placement = _placement_transform(
        ;
        at=at,
        scale=scale,
        rotate=rotate,
        deg=deg,
        rotation=rotation,
        inclination_azimut=inclination_azimut,
        inclination_angle=inclination_angle,
        transform=transform,
    )
    object_transformation = if unit_factor == 1.0
        placement
    else
        _compose_transformation(placement, scale3(unit_factor))
    end
    source_instance_id = builder.next_source_instance_id
    _transform_object!(
        obj,
        object_transformation;
        source_instance_id=source_instance_id,
        source_owner=source_owner,
    )
    _store_ops_placement_metadata!(
        obj,
        placement;
        at=at,
        scale=scale,
        rotate=rotate,
        deg=deg,
        rotation=rotation,
        inclination_azimut=inclination_azimut,
        inclination_angle=inclination_angle,
        transform=transform,
    )
    next_node_id = Ref(builder.next_node_id)
    _relabel_node_ids!(obj, next_node_id)
    builder.next_node_id = next_node_id[]
    MultiScaleTreeGraph.addchild!(builder.mtg, obj)
    builder.next_source_instance_id = source_instance_id + 1
    return builder
end

function add_object!(builder::SceneBuilder, path::AbstractString; type::AbstractString="object", kwargs...)
    mtg_type = typeof(MultiScaleTreeGraph.node_mtg(builder.mtg))
    add_object!(
        builder,
        _read_scene_object(path; type=type, mtg_type=mtg_type);
        type=type,
        file_path=path,
        kwargs...,
    )
end

"""
    add_plant!(builder::SceneBuilder, plant; group, id, kwargs...)
    add_plant!(builder::SceneBuilder, path::AbstractString; group, id, kwargs...)

Add a plant object to a scene being assembled with [`make_scene`](@ref).

This is a semantic alias for [`add_object!`](@ref) with the same placement and
metadata keywords. Use it for plant MTGs or plant files when the scene contains
both biological plants and non-plant objects.

Required keywords:

- `group`: functional group or treatment label, stored on the object root.
- `id`: plant id, stored as `:id`, `:object_id`, and `:plantID`.

Common placement keywords include `at`, `scale`, `rotate`, `deg`, `rotation`,
`inclination_azimut`, `inclination_angle`, and `transform`; see
[`add_object!`](@ref) for the full behavior.

The input MTG is deep-copied before placement, so the same loaded plant can be
added more than once with different ids or positions.
"""
add_plant!(builder::SceneBuilder, plant; group::AbstractString, id::Integer, kwargs...) =
    add_object!(builder, plant; group=group, id=id, kwargs...)

add_plant!(builder::SceneBuilder, path::AbstractString; group::AbstractString, id::Integer, kwargs...) =
    add_object!(builder, path; group=group, id=id, kwargs...)

function _add_ground_nodes!(
    mtg,
    bounds::NTuple{4,Float64};
    z::Real=0.0,
    nx::Int=9,
    ny::Int=9,
    group::AbstractString="pavement",
    type::AbstractString="Cobblestone",
    id::Integer=-1,
    kwargs...,
)
    xmin, ymin, xmax, ymax = bounds
    x_edges = collect(range(Float64(xmin), Float64(xmax), length=nx + 1))
    y_edges = collect(range(Float64(ymin), Float64(ymax), length=ny + 1))
    root_scale = MultiScaleTreeGraph.scale(mtg)
    mtg_type = typeof(MultiScaleTreeGraph.node_mtg(mtg))
    next_id = MultiScaleTreeGraph.max_id(mtg) + 1

    for ix in 1:nx, iy in 1:ny
        x0 = x_edges[ix]
        x1 = x_edges[ix+1]
        y0 = y_edges[iy]
        y1 = y_edges[iy+1]
        points = GeometryBasics.Point3f[
            GeometryBasics.Point3f(Float32(x0), Float32(y0), Float32(z)),
            GeometryBasics.Point3f(Float32(x1), Float32(y0), Float32(z)),
            GeometryBasics.Point3f(Float32(x1), Float32(y1), Float32(z)),
            GeometryBasics.Point3f(Float32(x0), Float32(y1), Float32(z)),
        ]
        faces = Face3[Face3(1, 2, 3), Face3(1, 3, 4)]
        mesh = GeometryBasics.Mesh(points, faces)
        nid = next_id
        next_id += 1
        attrs = Dict{Symbol,Any}(
            :geometry => Geometry(ref_mesh=RefMesh("$(group)_$(nid)", mesh)),
            :group => String(group),
            :functional_group => String(group),
            :type => String(type),
            :id => Int(id),
            :object_id => Int(id),
            :source_topology_id => nid,
        )
        for (k, v) in kwargs
            attrs[Symbol(k)] = v
        end
        MultiScaleTreeGraph.Node(
            nid,
            mtg,
            mtg_type(:+, Symbol(type), nid, root_scale + 1),
            attrs,
        )
    end

    haskey(mtg, :geometry) && (mtg[:geometry] = nothing)
    return mtg
end

"""
    add_ground!(builder::SceneBuilder; z=0.0, nx=9, ny=9, xy_bounds=nothing,
                group="pavement", type="Cobblestone", id=-1, kwargs...)
    add_ground!(scene::SceneGeometry; z=0.0, nx=9, ny=9, xy_bounds=nothing,
                group="pavement", type="Cobblestone", id=-1, kwargs...)

Add a rectangular ground mesh to a scene.

The ground is represented as a regular `nx` by `ny` grid of quadrilateral cells,
triangulated as two faces per cell. The grid is inserted directly in the scene
MTG as geometry-bearing child nodes. Each cell receives a `Geometry` with a
single `RefMesh`, plus the following attributes:

- `group` and `functional_group`: set from `group`
- `type`: set from `type`
- `id` and `object_id`: set from `id`
- `source_topology_id`: set to the generated node id
- any extra keyword arguments passed through `kwargs...`

By default, the ground extent comes from the scene domain:

- for a `SceneBuilder`, from `make_scene(domain=...)`
- for a `SceneGeometry`, from `scene.scene_xy_bounds`

Pass `xy_bounds=(xmin, ymin, xmax, ymax)` to override that extent. The `z`
keyword sets the elevation of all ground vertices.

When called inside a `make_scene do builder ... end` block, this method mutates
the builder and returns it. When called on an already prepared `SceneGeometry`,
it mutates the backing MTG, refreshes the merged scene geometry, and returns the
updated `SceneGeometry`.

# Examples

```julia
scene = make_scene(domain=(0.0, 0.0, 8.0, 4.0)) do builder
    add_ground!(builder; nx=8, ny=4, group="ground", type="Ground")
end
```

```julia
add_ground!(
    scene;
    xy_bounds=(-1.0, -1.0, 1.0, 1.0),
    z=-0.02,
    nx=2,
    ny=2,
    material=:soil,
)
```
"""
function add_ground!(
    scene::SceneGeometry;
    z::Real=0.0,
    nx::Int=9,
    ny::Int=9,
    xy_bounds=nothing,
    group::AbstractString="pavement",
    type::AbstractString="Cobblestone",
    id::Integer=-1,
    kwargs...,
)
    scene.mtg === nothing && error("add_ground! requires an MTG-backed scene.")
    bounds = xy_bounds === nothing ? scene.scene_xy_bounds : _coerce_scene_domain(xy_bounds)
    bounds === nothing && error("Ground bounds are undefined. Pass `xy_bounds=` or use a scene with a domain.")
    _add_ground_nodes!(scene.mtg, bounds; z=z, nx=nx, ny=ny, group=group, type=type, id=id, kwargs...)

    scene.scene_xy_bounds = bounds
    return _refresh_scene!(scene)
end

function add_ground!(
    builder::SceneBuilder;
    z::Real=0.0,
    nx::Int=9,
    ny::Int=9,
    xy_bounds=nothing,
    group::AbstractString="pavement",
    type::AbstractString="Cobblestone",
    id::Integer=-1,
    kwargs...,
)
    bounds = xy_bounds === nothing ? builder.domain : _coerce_scene_domain(xy_bounds)
    bounds === nothing && error("Ground bounds are undefined. Pass `domain=` to `make_scene` or `xy_bounds=` to `add_ground!`.")
    _add_ground_nodes!(builder.mtg, bounds; z=z, nx=nx, ny=ny, group=group, type=type, id=id, kwargs...)
    builder.domain = bounds
    builder.next_node_id = max(builder.next_node_id, MultiScaleTreeGraph.max_id(builder.mtg) + 1)
    return builder
end

"""
    make_scene(f; domain, mtg_type=NodeMTG, source_path="interactive.scene",
               units=SceneUnits(), ...)
    make_scene(; domain, mtg_type=NodeMTG, source_path="interactive.scene",
               units=SceneUnits(), ...)

Create a scene root, run the builder callback `f`, and return a prepared
[`SceneGeometry`](@ref).

This is the recommended high-level scene assembly API. The callback receives a
[`SceneBuilder`](@ref); call [`add_plant!`](@ref), [`add_object!`](@ref), and
[`add_ground!`](@ref) inside the callback to populate the scene.

Keyword arguments:

- `domain`: required scene XY domain `(xmin, ymin, xmax, ymax)`. It is stored as
  scene dimensions and used as the default extent for [`add_ground!`](@ref).
- `mtg_type`: MTG encoding type used for the scene root. Keep it consistent
  with the objects added to the scene, e.g. `NodeMTG` with `NodeMTG` objects or
  `MutableNodeMTG` with `MutableNodeMTG` objects.
- `source_path`: provenance label stored in the returned [`SceneGeometry`](@ref).
- `compute_area`: compute per-node surface areas.
- `compute_barycenter`: compute per-node area-weighted barycenters.
- `source_topology_id`: preserve source topology ids when available.
- `units`: physical length unit used to interpret all numeric scene coordinates.
  Domain bounds, placement coordinates, and generated ground coordinates use
  this unit.

Objects added through the builder are relabelled as they are inserted, so
independent object roots with overlapping ids can safely share one scene without
rebuilding the full attribute store after each insertion. After the callback
returns, `make_scene` calls [`prepare_scene`](@ref). The returned value is a
[`SceneGeometry`](@ref); use
`scene.mtg` when a function expects the scene MTG, for example
`plantviz(scene.mtg)` or `write_ops(file, scene.mtg)`.

# Examples

```julia
scene = make_scene(domain=(0.0, 0.0, 8.0, 4.0)) do builder
    add_plant!(builder, plant; group="plants", id=1, at=(1.0, 1.0, 0.0))
    add_ground!(builder; nx=8, ny=4)
end
```

```julia
scene = make_scene(
    domain=(0.0, 0.0, 8.0, 4.0);
    mtg_type=MutableNodeMTG,
) do builder
    add_plant!(builder, mutable_plant; group="plants", id=1)
end
```
"""
function make_scene(
    f::Function;
    domain,
    mtg_type=MultiScaleTreeGraph.NodeMTG,
    source_path::AbstractString="interactive.scene",
    compute_area::Bool=true,
    compute_barycenter::Bool=true,
    source_topology_id::Bool=true,
    units::SceneUnits=SceneUnits(),
)
    bounds = _coerce_scene_domain(domain)
    root = _scene_root(bounds; mtg_type=mtg_type)
    builder = SceneBuilder(
        root,
        bounds,
        String(source_path),
        compute_area,
        compute_barycenter,
        source_topology_id,
        MultiScaleTreeGraph.max_id(root) + 1,
        1,
        units,
    )
    f(builder)
    return prepare_scene(
        builder.mtg;
        source_path=builder.source_path,
        scene_xy_bounds=builder.domain,
        relabel_ids=false,
        compute_area=compute_area,
        compute_barycenter=compute_barycenter,
        source_topology_id=source_topology_id,
        units=builder.units,
    )
end

function make_scene(;
    domain,
    mtg_type=MultiScaleTreeGraph.NodeMTG,
    source_path::AbstractString="interactive.scene",
    compute_area::Bool=true,
    compute_barycenter::Bool=true,
    source_topology_id::Bool=true,
    units::SceneUnits=SceneUnits(),
)
    make_scene(
        identity;
        domain=domain,
        mtg_type=mtg_type,
        source_path=source_path,
        compute_area=compute_area,
        compute_barycenter=compute_barycenter,
        source_topology_id=source_topology_id,
        units=units,
    )
end
