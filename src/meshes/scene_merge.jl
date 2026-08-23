"""
    StaticGeometryJob

Typed scene-materialization job for classic `RefMesh + transformation` geometries.
"""
struct StaticGeometryJob{ME,TR,S}
    seq::Int
    node_id::Int
    base_mesh::ME
    taper::Bool
    dUp::S
    dDwn::S
    transformation::TR
end

"""
    GenericGeometryJob

Typed fallback job for additional geometry source types materialized through
`geometry_to_mesh(geom)`.
"""
struct GenericGeometryJob{G}
    seq::Int
    node_id::Int
    geometry::G
end

mutable struct GeometryJobBatches
    static::Dict{DataType,Any}
    generic::Dict{DataType,Any}
end

GeometryJobBatches() = GeometryJobBatches(Dict{DataType,Any}(), Dict{DataType,Any}())

# Compilation-time ownership snapshot. A positive `owner_node_id` is an
# existing stamp, a negative value is an unstamped default self-owner, and zero
# is an unstamped node requiring the source root's explicit resolver. The other
# fields are already known, so scene preparation never looks ownership up twice.
struct _CompiledSceneOwnership
    source_instance_id::Int
    source_node_id::Int
    owner_node_id::Int
    source_root_index::Int
end

@inline function _push_typed_job!(dict::Dict{DataType,Any}, job::J) where {J}
    key = J
    if haskey(dict, key)
        push!(dict[key]::Vector{J}, job)
    else
        dict[key] = J[job]
    end
    return nothing
end

@inline function _compile_node_geometry_jobs!(
    batches::GeometryJobBatches,
    seq::Int,
    node_id::Int,
    geom::Geometry,
)
    job = StaticGeometryJob(
        seq,
        node_id,
        geom.ref_mesh.mesh,
        geom.ref_mesh.taper,
        geom.dUp,
        geom.dDwn,
        geom.transformation,
    )
    _push_typed_job!(batches.static, job)
    return nothing
end

@inline function _compile_node_geometry_jobs!(
    batches::GeometryJobBatches,
    seq::Int,
    node_id::Int,
    geom,
)
    job = GenericGeometryJob(seq, node_id, geom)
    _push_typed_job!(batches.generic, job)
    return nothing
end

function _compile_geometry_jobs!(
    batches::GeometryJobBatches,
    mtg;
    seq::Base.RefValue{Int},
    filter_fun=nothing,
    symbol=nothing,
    scale=nothing,
    link=nothing,
    geometry_nodes=nothing,
    geometry_ownership=nothing,
    source_instance_id=nothing,
    source_root_index::Int=0,
    source_namespace_was_missing::Bool=false,
    source_owner_resolver=nothing,
)
    any_node_selected = false
    collect_ownership = geometry_ownership !== nothing
    # Ownership stamps may live on non-geometric botanical owners. Inspect all
    # nodes in the same traversal that compiles geometry so cross-instance
    # reparenting cannot hide on an owner anchor.
    preflight_all_nodes = collect_ownership
    traversal_filter = preflight_all_nodes ? nothing : filter_fun
    traversal_symbol = preflight_all_nodes ? nothing : symbol
    traversal_scale = preflight_all_nodes ? nothing : scale
    traversal_link = preflight_all_nodes ? nothing : link

    MultiScaleTreeGraph.traverse!(
        mtg;
        filter_fun=traversal_filter,
        symbol=traversal_symbol,
        scale=traversal_scale,
        link=traversal_link,
    ) do node
        stored_ownership = if !collect_ownership
            nothing
        else
            _preflight_scene_ownership(
                node,
                source_instance_id,
                source_namespace_was_missing,
            )
        end
        if preflight_all_nodes && !MultiScaleTreeGraph.is_filtered(
            node,
            scale,
            symbol,
            link,
            filter_fun,
        )
            return nothing
        end
        has_geometry(node) || return nothing
        geom = node[:geometry]
        any_node_selected = true
        seq[] += 1
        geometry_nodes === nothing || push!(geometry_nodes, node)
        geometry_ownership === nothing || push!(
            geometry_ownership,
            _compiled_scene_ownership(
                node,
                source_instance_id,
                source_root_index,
                stored_ownership,
                source_owner_resolver,
            ),
        )
        _compile_node_geometry_jobs!(batches, seq[], MultiScaleTreeGraph.node_id(node), geom)
    end

    return any_node_selected
end


function compile_geometry_jobs(
    mtg;
    filter_fun=nothing,
    symbol=nothing,
    scale=nothing,
    link=nothing,
    geometry_nodes=nothing,
)
    batches = GeometryJobBatches()
    any_node_selected = _compile_geometry_jobs!(
        batches,
        mtg;
        seq=Ref(0),
        filter_fun=filter_fun,
        symbol=symbol,
        scale=scale,
        link=link,
        geometry_nodes=geometry_nodes,
    )

    return batches, any_node_selected
end


function _compile_scene_geometry_jobs(
    source_roots;
    newly_namespaced_roots,
    filter_fun=nothing,
    symbol=nothing,
    scale=nothing,
    link=nothing,
    geometry_nodes,
    geometry_ownership,
)
    batches = GeometryJobBatches()
    seq = Ref(0)
    any_node_selected = false
    for (source_root_index, root) in enumerate(source_roots)
        source_instance_id = _scene_positive_int_attribute(
            root,
            _SCENE_SOURCE_INSTANCE_ID_ATTRIBUTE,
        )
        source_instance_id isa Int || error(
            "Scene source namespaces must be normalized before compiling geometry.",
        )
        source_owner_resolver = _root_source_owner_resolver(root)
        any_node_selected |= _compile_geometry_jobs!(
            batches,
            root;
            seq=seq,
            filter_fun=filter_fun,
            symbol=symbol,
            scale=scale,
            link=link,
            geometry_nodes=geometry_nodes,
            geometry_ownership=geometry_ownership,
            source_instance_id=source_instance_id,
            source_root_index=source_root_index,
            source_namespace_was_missing=newly_namespaced_roots[source_root_index],
            source_owner_resolver=source_owner_resolver,
        )
    end
    return batches, any_node_selected
end

function _materialize_batch!(
    seqs::Vector{Int},
    node_ids::Vector{Int},
    meshes::Vector{Any},
    ne_per_mesh::Vector{Int},
    jobs::Vector{StaticGeometryJob{ME,TR,S}},
) where {ME,TR,S}
    @inbounds for job in jobs
        local_mesh = if job.taper
            taper(job.base_mesh, job.dUp, job.dDwn)
        else
            job.base_mesh
        end
        m = apply_transformation_to_mesh(job.transformation, local_mesh)
        m === nothing && continue
        push!(seqs, job.seq)
        push!(node_ids, job.node_id)
        push!(meshes, m)
        push!(ne_per_mesh, nelements(m))
    end
    return nothing
end

function _materialize_batch!(
    seqs::Vector{Int},
    node_ids::Vector{Int},
    meshes::Vector{Any},
    ne_per_mesh::Vector{Int},
    jobs::Vector{GenericGeometryJob{G}},
) where {G}
    @inbounds for job in jobs
        m = geometry_to_mesh(job.geometry)
        m === nothing && continue
        push!(seqs, job.seq)
        push!(node_ids, job.node_id)
        push!(meshes, m)
        push!(ne_per_mesh, nelements(m))
    end
    return nothing
end

function _materialize_geometry_jobs(batches::GeometryJobBatches)
    seqs = Int[]
    meshes = Any[]
    node_ids = Int[]
    ne_per_mesh = Int[]

    for jobs in values(batches.static)
        _materialize_batch!(seqs, node_ids, meshes, ne_per_mesh, jobs)
    end
    for jobs in values(batches.generic)
        _materialize_batch!(seqs, node_ids, meshes, ne_per_mesh, jobs)
    end

    if !issorted(seqs)
        p = sortperm(seqs)
        seqs = seqs[p]
        meshes = meshes[p]
        node_ids = node_ids[p]
        ne_per_mesh = ne_per_mesh[p]
    end

    return meshes, node_ids, ne_per_mesh, seqs
end

function materialize_geometry_jobs(batches::GeometryJobBatches)
    meshes, node_ids, ne_per_mesh, _ = _materialize_geometry_jobs(batches)
    return meshes, node_ids, ne_per_mesh
end

function _materialize_merged_geometry(batches::GeometryJobBatches)
    meshes, node_ids, ne_per_mesh, seqs = _materialize_geometry_jobs(batches)
    isempty(meshes) && error("No geometry meshes found to merge.")

    face2node = Vector{Int}(undef, sum(ne_per_mesh))
    ofs = 0
    @inbounds for i in eachindex(meshes)
        ne = ne_per_mesh[i]
        if ne > 0
            face2node[ofs+1:ofs+ne] .= node_ids[i]
            ofs += ne
        end
    end

    merged_mesh = merge_simple_meshes(meshes)
    return merged_mesh, face2node, node_ids, ne_per_mesh, seqs
end

function _build_merged_mesh_with_map(
    ::Val{false},
    mtg;
    filter_fun=nothing,
    symbol=nothing,
    scale=nothing,
    link=nothing,
    source_roots=nothing,
    newly_namespaced_roots=nothing,
)
    batches, any_node_selected = if source_roots === nothing
        compile_geometry_jobs(
            mtg;
            filter_fun=filter_fun,
            symbol=symbol,
            scale=scale,
            link=link,
        )
    else
        geometry_nodes = typeof(mtg)[]
        geometry_ownership = _CompiledSceneOwnership[]
        _compile_scene_geometry_jobs(
            source_roots;
            newly_namespaced_roots=newly_namespaced_roots,
            filter_fun=filter_fun,
            symbol=symbol,
            scale=scale,
            link=link,
            geometry_nodes=geometry_nodes,
            geometry_ownership=geometry_ownership,
        )
    end
    any_node_selected || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")

    merged_mesh, face2node, _, _, _ = _materialize_merged_geometry(batches)
    return merged_mesh, face2node
end

function _build_merged_mesh_with_map(
    ::Val{true},
    mtg;
    filter_fun=nothing,
    symbol=nothing,
    scale=nothing,
    link=nothing,
    source_roots=nothing,
    newly_namespaced_roots=nothing,
)
    geometry_nodes = typeof(mtg)[]
    geometry_ownership =
        source_roots === nothing ? nothing : _CompiledSceneOwnership[]
    batches, any_node_selected = if source_roots === nothing
        compile_geometry_jobs(
            mtg;
            filter_fun=filter_fun,
            symbol=symbol,
            scale=scale,
            link=link,
            geometry_nodes=geometry_nodes,
        )
    else
        _compile_scene_geometry_jobs(
            source_roots;
            newly_namespaced_roots=newly_namespaced_roots,
            filter_fun=filter_fun,
            symbol=symbol,
            scale=scale,
            link=link,
            geometry_nodes=geometry_nodes,
            geometry_ownership=geometry_ownership,
        )
    end
    any_node_selected || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")

    merged_mesh, face2node, node_ids, ne_per_mesh, seqs =
        _materialize_merged_geometry(batches)
    return merged_mesh,
        face2node,
        node_ids,
        ne_per_mesh,
        geometry_nodes,
        geometry_ownership,
        seqs
end

# Backwards-compatible private wrapper. Hot internal paths dispatch directly on
# `Val` so their two- and seven-value return types remain fully inferred.
function _build_merged_mesh_with_map(
    mtg;
    filter_fun=nothing,
    symbol=nothing,
    scale=nothing,
    link=nothing,
    collect_nodes::Bool=false,
    source_roots=nothing,
    newly_namespaced_roots=nothing,
)
    return _build_merged_mesh_with_map(
        Val(collect_nodes),
        mtg;
        filter_fun=filter_fun,
        symbol=symbol,
        scale=scale,
        link=link,
        source_roots=source_roots,
        newly_namespaced_roots=newly_namespaced_roots,
    )
end

"""
    build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)

Traverse selected MTG nodes and merge their geometry meshes into a single mesh.

Returns a merged `mesh` and a `face2node::Vector{Int}` mapping each face index in the
merged mesh to the originating MTG node id (`MultiScaleTreeGraph.node_id(node)`).
"""
function build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    return _build_merged_mesh_with_map(
        Val(false),
        mtg;
        filter_fun=filter_fun,
        symbol=symbol,
        scale=scale,
        link=link,
    )
end

"""
    build_merged_mesh_with_map_threaded(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)

Alias to [`build_merged_mesh_with_map`](@ref). Threaded implementation removed.
"""
function build_merged_mesh_with_map_threaded(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    build_merged_mesh_with_map(mtg; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link)
end

"""
    merge_simple_meshes(meshes) -> mesh

Merge a collection of meshes into a single mesh in one pass by concatenating
vertices and reindexing faces with running offsets.
"""
function merge_simple_meshes(meshes::AbstractVector)
    isempty(meshes) && error("No meshes to merge.")
    _merge_meshes(meshes)
end

"""
    scene_version(mtg) -> Int

Return the scene version counter stored on the MTG root (default 0).
"""
function scene_version(mtg)
    root = MultiScaleTreeGraph.get_root(mtg)
    return hasproperty(root, :_scene_version) ? root[:_scene_version] : 0
end

"""
    bump_scene_version!(mtg; by=1)

Increment the scene version to invalidate any cached merged scene.
"""
function bump_scene_version!(mtg; by=1)
    root = MultiScaleTreeGraph.get_root(mtg)
    root[:_scene_version] = scene_version(mtg) + by
    root[:_scene_cache] = nothing
    return root[:_scene_version]
end

"""
    scene_cache_key(mtg; symbol=nothing, scale=nothing, link=nothing, filter_fun=nothing) -> UInt

Compute a stable cache key for the current scene rendering request.
"""
function scene_cache_key(mtg; symbol=nothing, scale=nothing, link=nothing, filter_fun=nothing)
    ver = scene_version(mtg)
    fid = isnothing(filter_fun) ? 0 : objectid(filter_fun)
    return hash((ver, symbol, scale, link, fid))
end

"""
    get_cached_scene(mtg, key) -> Union{Nothing,NamedTuple}

Retrieve the single cached merged scene if it matches `key`.
Returns a NamedTuple with `(hash, mesh, face2node)` or `nothing`.
"""
function get_cached_scene(mtg, key)
    root = MultiScaleTreeGraph.get_root(mtg)
    cache = root[:_scene_cache]
    cache === nothing && return nothing
    (getfield(cache, :hash) == key) || return nothing
    return cache
end

"""
    set_cached_scene!(mtg, key; mesh, face2node=nothing)

Store a single merged scene cache with associated `key` hash. Only mesh and face2node are cached.
"""
function set_cached_scene!(mtg, key; mesh, face2node=nothing)
    root = MultiScaleTreeGraph.get_root(mtg)
    root[:_scene_cache] = (hash=key, mesh=mesh, face2node=face2node)
    return nothing
end
