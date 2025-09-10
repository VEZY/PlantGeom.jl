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
            m = refmesh_to_mesh(node)
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
            face2node[ofs+1:ofs+ne] .= node_ids[i]
            ofs += ne
        end
    end

    merged_mesh = merge_simple_meshes(meshes)
    return merged_mesh, face2node
end

"""
    build_merged_mesh_with_map_threaded(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)

Threaded variant of [`build_merged_mesh_with_map`] that parallelizes vertex copy and
connectivity reindexing across meshes. Preserves original mesh order.
"""
function build_merged_mesh_with_map_threaded(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    #! not used. Benchmarks show no benefit of this one over the single-threaded one, even for opf_large
    meshes = Meshes.SimpleMesh[]
    node_ids = Int[]
    nv_per_mesh = Int[]
    ne_per_mesh = Int[]
    any_node_selected = Ref(false)

    MultiScaleTreeGraph.traverse!(mtg; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
        geom = node[:geometry]
        if geom !== nothing
            any_node_selected[] = true
            m = refmesh_to_mesh(node)
            push!(meshes, m)
            push!(node_ids, MultiScaleTreeGraph.node_id(node))
            push!(nv_per_mesh, Meshes.nvertices(m))
            push!(ne_per_mesh, Meshes.nelements(m))
        end
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
    length(meshes) > 0 || error("No geometry meshes found to merge.")

    # face2node mapping (sequential, contiguous slices)
    total_elems = sum(ne_per_mesh)
    face2node = Vector{Int}(undef, total_elems)
    ofs_e = 0
    @inbounds for i in eachindex(meshes)
        ne = ne_per_mesh[i]
        if ne > 0
            face2node[ofs_e+1:ofs_e+ne] .= node_ids[i]
            ofs_e += ne
        end
    end

    # Prefix sums for vertex offsets
    n = length(meshes)
    total_pts = sum(nv_per_mesh)
    v_offsets = Vector{Int}(undef, n)
    s = 0
    @inbounds for i in 1:n
        v_offsets[i] = s
        s += nv_per_mesh[i]
    end

    # Allocate final points; infer PT from first mesh
    PT = eltype(collect(Meshes.vertices(meshes[1])))
    points = Vector{PT}(undef, total_pts)

    # Build connectivity blocks per mesh (typed per-block), in parallel
    connec_blocks = Vector{Vector}(undef, n)
    Threads.@threads for i in 1:n
        m = meshes[i]
        voff = v_offsets[i]
        # Copy vertices into final array at slice
        v = collect(Meshes.vertices(m))
        @inbounds points[voff+1:voff+length(v)] = v

        # Build typed connectivity block
        ne = ne_per_mesh[i]
        if ne == 0
            connec_blocks[i] = Vector{Any}(undef, 0)
        else
            topo = Meshes.topology(m)
            e1 = first(Meshes.elements(topo))
            CTk = typeof(Meshes.connect(Meshes.indices(e1), Meshes.pltype(e1)))
            blk = Vector{CTk}(undef, ne)
            j = 0
            for e in Meshes.elements(topo)
                PL = Meshes.pltype(e)
                c = Meshes.indices(e)
                c′ = ntuple(k -> c[k] + voff, length(c))
                j += 1
                @inbounds blk[j] = Meshes.connect(c′, PL)
            end
            connec_blocks[i] = blk
        end
    end

    connec = reduce(vcat, connec_blocks)
    merged_mesh = Meshes.SimpleMesh(points, connec)
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
