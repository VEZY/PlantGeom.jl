"""
    build_merged_mesh(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)

Traverse selected MTG nodes and merge their geometry meshes into a single `Meshes.SimpleMesh`.
Uses `Meshes.merge` to avoid manual index offset handling.
"""
function build_merged_mesh(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    meshes = Meshes.SimpleMesh[]
    any_node_selected = Ref(false)
    MultiScaleTreeGraph.traverse!(mtg; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
        if node[:geometry] !== nothing
            any_node_selected[] = true
            m = node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh
            m === nothing || push!(meshes, m) #! merge the nodes directly here? 
        end
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
    length(meshes) > 0 || error("No geometry meshes found to merge.")

    merged_mesh = meshes[1]
    for i in 2:length(meshes)
        merged_mesh = Meshes.merge(merged_mesh, meshes[i])
    end
    return merged_mesh
end

"""
    build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)

Like [`build_merged_mesh`] but also returns a `face2node::Vector{Int}` mapping each face
index in the merged mesh to the originating MTG node id.
"""
function build_merged_mesh_with_map(mtg; filter_fun=nothing, symbol=nothing, scale=nothing, link=nothing)
    meshes = Meshes.SimpleMesh[]
    face2node = Int[]
    any_node_selected = Ref(false)
    MultiScaleTreeGraph.traverse!(mtg; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
        if node[:geometry] !== nothing
            any_node_selected[] = true
            m = node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh
            if m !== nothing
                push!(meshes, m) #! merge the nodes directly here? 
                append!(face2node, fill(MultiScaleTreeGraph.node_id(node), Meshes.nelements(m)))
            end
        end
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
    length(meshes) > 0 || error("No geometry meshes found to merge.")

    merged_mesh = meshes[1] #! merge the nodes directly up there, or at least use reduce here
    for i in 2:length(meshes)
        merged_mesh = Meshes.merge(merged_mesh, meshes[i])
    end
    return merged_mesh, face2node
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
    # Optionally clear cache
    haskey(root, :_scene_cache) && empty!(root[:_scene_cache])
    return root[:_scene_version]
end

"""
    scene_cache_key(mtg; merged=true, colorant_tag=:solid, color_id=nothing,
                    colormap_id=nothing, colorrange_id=nothing,
                    symbol=nothing, scale=nothing, link=nothing, filter_fun=nothing) -> UInt

Compute a stable cache key for the current scene rendering request.
"""
function scene_cache_key(mtg; merged=true, colorant_tag=:solid, color_id=nothing,
    colormap_id=nothing, colorrange_id=nothing,
    symbol=nothing, scale=nothing, link=nothing, filter_fun=nothing)
    ver = scene_version(mtg)
    fid = isnothing(filter_fun) ? 0 : objectid(filter_fun)
    return hash((ver, merged, colorant_tag, color_id, colormap_id, colorrange_id, symbol, scale, link, fid))
end

"""
    get_cached_scene(mtg, key) -> Union{Nothing,NamedTuple}

Retrieve a cached merged scene for `key`. Returns a NamedTuple with
`(mesh, vertex_colors, face2node)` if present.
"""
function get_cached_scene(mtg, key)
    root = MultiScaleTreeGraph.get_root(mtg)
    (!haskey(root, :_scene_cache) || isnothing(root[:_scene_cache])) && return nothing
    cache = root[:_scene_cache]
    get(cache, key, nothing)
end

"""
    set_cached_scene!(mtg, key; mesh, vertex_colors=nothing, face2node=nothing)

Store a merged scene in the cache.
"""
function set_cached_scene!(mtg, key; mesh, vertex_colors=nothing, face2node=nothing)
    root = MultiScaleTreeGraph.get_root(mtg)
    if !haskey(root, :_scene_cache)
        root[:_scene_cache] = Dict{UInt,NamedTuple}()
    end
    root[:_scene_cache][key] = (mesh=mesh, vertex_colors=vertex_colors, face2node=face2node)
    return nothing
end

