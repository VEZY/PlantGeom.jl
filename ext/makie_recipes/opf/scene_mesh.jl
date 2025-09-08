"""
    scene_mesh!(opf, filter_fun, symbol, scale, link, cache=true)

Get (or compute and cache) the merged mesh from all node meshes and the face2node mapping (mesh face to MTG node) for the given OPF.

# Attributes

- `opf`: The OPF object containing the scene information.
- `filter_fun`: A function to filter the nodes to include in the mesh.
- `symbol`: The symbol representing the mesh.
- `scale`: The scale factor to apply to the mesh.
- `link`: The link to the original mesh.
- `cache`: Whether to cache the result (used mostly for benchmarking).
"""
function scene_mesh!(opf, filter_fun, symbol, scale, link, cache=true)

    if cache
        # Cache key based on refmesh color dict and filters
        key = PlantGeom.scene_cache_key(opf; merged=true, symbol=symbol, scale=scale, link=link, filter_fun=filter_fun)

        cached = PlantGeom.get_cached_scene(opf, key)
        !isnothing(cached) && return cached.mesh, cached.face2node
    end

    merged_mesh, face2node = PlantGeom.build_merged_mesh_with_map(opf; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link)

    cache && PlantGeom.set_cached_scene!(opf, key; mesh=merged_mesh, face2node=face2node)

    return merged_mesh, face2node
end