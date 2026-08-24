@deprecate geometry(; ref_mesh, ref_mesh_index=nothing, transformation=IdentityTransformation(), dUp=1.0, dDwn=1.0, mesh=nothing) Geometry(; ref_mesh, transformation=IdentityTransformation(), dUp=1.0, dDwn=1.0)

# Placement APIs now use the explicit `at=` keyword. Keyword-only renames cannot
# be represented safely with `@deprecate` because Julia does not dispatch on
# keyword names, so the affected methods call this helper directly.
function _deprecate_at_keyword!(func::Symbol, old::Symbol)
    Base.depwarn(
        "`$(func)(; $(old)=...)` is deprecated, use `$(func)(; at=...)` instead.",
        func,
    )
    return nothing
end

function viz(refmesh::T, args...; kwars...) where {T<:Union{RefMesh,AbstractVector{<:RefMesh}}}
    @warn "The `viz` function is deprecated, use `plantviz` instead."
    plantviz(refmesh, args...; kwars...)
end

function viz!(refmesh::T, args...; kwars...) where {T<:Union{RefMesh,AbstractVector{<:RefMesh}}}
    @warn "The `viz!` function is deprecated, use `plantviz!` instead."
    plantviz!(refmesh, args...; kwars...)
end

function viz(mesh::T, args...; kwars...) where {T<:MultiScaleTreeGraph.Node}
    @warn "The `viz` function is deprecated, use `plantviz` instead."
    plantviz(mesh, args...; kwars...)
end

function viz!(mesh::T, args...; kwars...) where {T<:MultiScaleTreeGraph.Node}
    @warn "The `viz!` function is deprecated, use `plantviz!` instead."
    plantviz!(mesh, args...; kwars...)
end

@noinline function _deprecate_emit_phytomer!()
    Base.depwarn(
        "`emit_phytomer!` is deprecated because it does not create a `:Phytomer` node; " *
        "use `emit_internode_leaf!` for the same internode/leaf emission behavior.",
        :emit_phytomer!,
    )
    return nothing
end

"""
    emit_phytomer!(parent; kwargs...)

Deprecated compatibility wrapper for [`emit_internode_leaf!`](@ref).

Despite its historical name, this function does not create a `:Phytomer` node.
It preserves the former behavior of emitting an `:Internode`, a `:Leaf`, or both.
"""
function emit_phytomer!(
    parent::MultiScaleTreeGraph.Node;
    internode=NamedTuple(),
    leaf=NamedTuple(),
    internode_index::Integer=0,
    leaf_index::Integer=0,
    scale=nothing,
    bump_scene::Bool=true,
)
    _deprecate_emit_phytomer!()
    return emit_internode_leaf!(
        parent;
        internode=internode,
        leaf=leaf,
        internode_index=internode_index,
        leaf_index=leaf_index,
        scale=scale,
        bump_scene=bump_scene,
    )
end
