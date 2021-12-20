"""
    nvertices(meshes::RefMeshes)

Return the number of vertices for each reference mesh as a dict of id => nvertices
"""
function nvertices(meshes::RefMeshes)
    nvert = Dict{Int,Int}()
    for (key, value) in meshes.meshes
        push!(nvert, key => nvertices(value.mesh))
    end

    return nvert
end

"""
    nelements(meshes::RefMeshes)

Return the number of elements for each reference mesh as a dict of id => nelements
"""
function nelements(meshes::RefMeshes)
    nelem = Dict{Int,Int}()
    for (key, value) in meshes.meshes
        push!(nelem, key => nelements(value.mesh))
    end

    return nelem
end
