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

function compile_geometry_jobs(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    batches = GeometryJobBatches()
    any_node_selected = false
    seq = 0

    MultiScaleTreeGraph.traverse!(mtg; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
        has_geometry(node) || return nothing
        geom = node[:geometry]
        any_node_selected = true
        seq += 1
        _compile_node_geometry_jobs!(batches, seq, MultiScaleTreeGraph.node_id(node), geom)
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

function materialize_geometry_jobs(batches::GeometryJobBatches)
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
        meshes = meshes[p]
        node_ids = node_ids[p]
        ne_per_mesh = ne_per_mesh[p]
    end

    return meshes, node_ids, ne_per_mesh
end

"""
    build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)

Traverse selected MTG nodes and merge their geometry meshes into a single mesh.

Returns a merged `mesh` and a `face2node::Vector{Int}` mapping each face index in the
merged mesh to the originating MTG node id (`MultiScaleTreeGraph.node_id(node)`).
"""
function build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    batches, any_node_selected = compile_geometry_jobs(
        mtg;
        filter_fun=filter_fun,
        symbol=symbol,
        scale=scale,
        link=link,
    )
    any_node_selected || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")

    meshes, node_ids, ne_per_mesh = materialize_geometry_jobs(batches)
    length(meshes) > 0 || error("No geometry meshes found to merge.")

    total_elems = sum(ne_per_mesh)
    face2node = Vector{Int}(undef, total_elems)
    ofs = 0
    @inbounds for i in eachindex(meshes)
        ne = ne_per_mesh[i]
        if ne > 0
            face2node[ofs+1:ofs+ne] .= node_ids[i]
            ofs += ne
        end
    end

    merged_mesh = merge_simple_meshes(meshes)
    return merged_mesh, face2node
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
