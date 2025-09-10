"""
    build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)

Traverse selected MTG nodes and merge their geometry meshes into a single `Meshes.SimpleMesh`.

Returns a merged `mesh::Meshes.SimpleMesh` and a `face2node::Vector{Int}` mapping each face
index in the merged mesh to the originating MTG node id.
"""
function build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    meshes = Meshes.SimpleMesh[]
    node_ids = Int[]
    ne_per_mesh = Int[]
    any_node_selected = Ref(false)

    MultiScaleTreeGraph.traverse!(mtg; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
        geom = node[:geometry]
        if geom !== nothing
            any_node_selected[] = true
            m = (geom.mesh === nothing) ? refmesh_to_mesh(node) : geom.mesh
            push!(meshes, m)
            push!(node_ids, MultiScaleTreeGraph.node_id(node))
            push!(ne_per_mesh, Meshes.nelements(m))
        end
    end

    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
    length(meshes) > 0 || error("No geometry meshes found to merge.")

    # Preallocate and fill face2node in one pass
    total_elems = sum(ne_per_mesh)
    face2node = Vector{Int}(undef, total_elems)
    ofs = 0
    @inbounds for i in eachindex(meshes)
        ne = ne_per_mesh[i]
        if ne > 0
            face2node[ofs + 1 : ofs + ne] .= node_ids[i]
            ofs += ne
        end
    end

    merged_mesh = merge_simple_meshes(meshes)
    return merged_mesh, face2node
end

"""
    merge_simple_meshes(meshes::AbstractVector{<:Meshes.SimpleMesh}) -> Meshes.SimpleMesh

Merge a collection of `Meshes.SimpleMesh` into a single mesh in one pass by
concatenating vertices and reindexing element connectivities with running offsets.
This avoids repeated pairwise merges and additional allocations.
"""
function merge_simple_meshes(meshes::AbstractVector{<:Meshes.SimpleMesh})
    isempty(meshes) && error("No meshes to merge.")

    # Single mapreduce pass with running offset for connectivity reindexing
    off = Ref(0)
    combine = (a, b) -> begin
        append!(a[1], b[1])
        append!(a[2], b[2])
        a
    end
    points, connec = mapreduce(
        m -> begin
            v = Meshes.vertices(m)
            elems = Meshes.elements(Meshes.topology(m))
            conns = map(elems) do e
                c = Meshes.indices(e)
                Meshes.connect(ntuple(i -> c[i] + off[], length(c)), Meshes.pltype(e))
            end
            off[] += length(v)
            (v, conns)
        end,
        combine,
        meshes
    )

    return Meshes.SimpleMesh(points, connec)
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
    # Invalidate single-entry cache
    root[:_scene_cache] = nothing
    return root[:_scene_version]
end

"""
    scene_cache_key(mtg; merged=true, colorant_tag=:solid, color_id=nothing,
                    colormap_id=nothing, colorrange_id=nothing,
                    symbol=nothing, scale=nothing, link=nothing, filter_fun=nothing) -> UInt

Compute a stable cache key for the current scene rendering request.
"""
function scene_cache_key(mtg; merged=true, symbol=nothing, scale=nothing, link=nothing, filter_fun=nothing)
    ver = scene_version(mtg)
    fid = isnothing(filter_fun) ? 0 : objectid(filter_fun)
    return hash((ver, merged, symbol, scale, link, fid))
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
    # Accept only if hash matches
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
