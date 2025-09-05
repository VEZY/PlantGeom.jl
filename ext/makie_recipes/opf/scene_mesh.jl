"""
    scene_mesh!(opf, filter_fun, symbol, scale, link)

Get (or compute and cache) the merged mesh from all node meshes and the face2node mapping (mesh face to MTG node) for the given OPF.
"""
function scene_mesh!(opf, filter_fun, symbol, scale, link)
    # Cache key based on refmesh color dict and filters
    key = PlantGeom.scene_cache_key(opf; merged=true, symbol=symbol, scale=scale, link=link, filter_fun=filter_fun)

    cached = PlantGeom.get_cached_scene(opf, key)
    !isnothing(cached) && return cached.mesh, cached.face2node

    merged_mesh, face2node = PlantGeom.build_merged_mesh_with_map(opf; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link)
    PlantGeom.set_cached_scene!(opf, key; mesh=merged_mesh, face2node=face2node)

    return merged_mesh, face2node
end