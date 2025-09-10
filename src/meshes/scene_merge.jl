"""
    build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)

Traverse selected MTG nodes and merge their geometry meshes into a single `Meshes.SimpleMesh`.

Returns a merged `mesh::Meshes.SimpleMesh` and a `face2node::Vector{Int}` mapping each face
index in the merged mesh to the originating MTG node id.
"""
function build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    meshes = Meshes.SimpleMesh[]
    face2node = Int[]
    any_node_selected = Ref(false)
    MultiScaleTreeGraph.traverse!(mtg; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
        if node[:geometry] !== nothing
            any_node_selected[] = true
            m = refmesh_to_mesh(node)
            push!(meshes, m) #! merge the nodes directly here? 
            append!(face2node, fill(MultiScaleTreeGraph.node_id(node), Meshes.nelements(m)))
        end
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
    length(meshes) > 0 || error("No geometry meshes found to merge.")

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

    # Collect vertex blocks and concatenate
    verts_blocks = map(m -> collect(Meshes.vertices(m)), meshes)
    points = vcat(verts_blocks...)

    # Compute running offsets for connectivity reindexing
    lens = map(length, verts_blocks)
    # offsets[i] = sum(lens[1:i-1])
    offsets = length(lens) == 0 ? Int[] : cumsum(vcat(0, lens[1:end-1]))

    # Map each mesh to its reindexed connectivity block
    connec_blocks = map(zip(meshes, offsets)) do (m, off)
        elems = collect(Meshes.elements(Meshes.topology(m)))
        map(elems) do e
            PL = Meshes.pltype(e)
            c = Meshes.indices(e)
            c′ = ntuple(i -> c[i] + off, length(c))
            Meshes.connect(c′, PL)
        end
    end
    connec = any(!isempty, connec_blocks) ? reduce(vcat, connec_blocks) : Any[]

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
