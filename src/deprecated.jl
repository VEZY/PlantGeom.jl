@deprecate geometry(; ref_mesh, ref_mesh_index=nothing, transformation=Identity(), dUp=1.0, dDwn=1.0, mesh=nothing) Geometry(; ref_mesh, transformation=Identity(), dUp=1.0, dDwn=1.0)

function viz(refmesh::T, args...; kwars...) where {T<:RefMesh}
    @warn "The `viz` function is deprecated, use `plantviz` instead."
    plantviz(refmesh, args..., kwars...)
end

function viz!(refmesh::T, args...; kwars...) where {T<:RefMesh}
    @warn "The `viz!` function is deprecated, use `plantviz!` instead."
    plantviz!(refmesh, args..., kwars...)
end

function viz(mesh::T, args...; kwars...) where {T<:MultiScaleTreeGraph.Node}
    @warn "The `viz` function is deprecated, use `plantviz` instead."
    plantviz(mesh, args..., kwars...)
end

function viz!(mesh::T, args...; kwars...) where {T<:MultiScaleTreeGraph.Node}
    @warn "The `viz!` function is deprecated, use `plantviz!` instead."
    plantviz!(mesh, args..., kwars...)
end