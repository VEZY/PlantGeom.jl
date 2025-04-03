"""
    merge_children_geometry!(mtg; from, into, delete=true, child_link_fun=new_child_link)

Simplifies the geometry of a MultiScaleTreeGraph (MTG) by merging low-scale geometries into an higher-scale geometry.

# Arguments

- `mtg`: The MultiScaleTreeGraph to process.
- `from`: The string for the type of nodes to simplify, this is the lower scale meshes that need to be merged. Can be a string or a vector of strings, *e.g.* ["Petiole", "Rachis"].
- `into`: The string for the type of nodes to merge into. Must be a single string, *e.g.* "Leaf".
- `delete`: A symbol indicating whether to delete the nodes or the geometry after merging:
  - `:none`: No deletion will be performed, the geometry is merged into the `into` nodes, and also kept as before in the `from` nodes.
  - `:nodes`: The nodes of type `from` will be deleted after merging.
  - `:geometry`: Only the geometry will be deleted, but the `from` nodes will remain in the MTG.
- `child_link_fun`: A function that takes a parent node targeted for deletion and returns the new links for their children. Required if `delete` is `true`.

# Returns

- Nothing. The function modifies the `mtg` in place.

# Notes

If no geometry is found in the children nodes of type `from`, an informational message is logged.
"""
function merge_children_geometry!(mtg; from, into, delete=:nodes, child_link_fun=new_child_link)
    @assert into isa AbstractString """`into` must be a single string, e.g. "Leaf"."""
    @assert delete in (:none, :nodes, :geometry) """`delete` must be either `:nodes` or `:geometry`."""
    delete == :nodes && @assert child_link_fun isa Function """`child_link_fun` must be a function that takes a parent node targeted for deletion, and returns the new links for their children."""

    # Traverse the tree and simplify the geometry
    MultiScaleTreeGraph.traverse!(mtg, symbol=into) do node_into
        meshes_vec = MultiScaleTreeGraph.traverse(node_into, filter_fun=x -> haskey(x, :geometry), type=Meshes.SimpleMesh, symbol=from) do node_from
            refmesh_to_mesh(node_from)
        end
        if isempty(meshes_vec)
            # First, test if we find any children nodes of type `from`:
            no_nodes_as_descendants = MultiScaleTreeGraph.descendants(node_into, symbol=from) |> isempty
            if no_nodes_as_descendants
                @info "No children nodes of type $from found in node $node_into"
            else
                @info "No geometry found in children nodes $from for node $node_into"
            end
        end
        # Build a new reference mesh out of the children nodes
        ref_mesh = RefMesh(string(into, MultiScaleTreeGraph.node_id(node_into)), reduce(merge, meshes_vec))
        node_into.geometry = Geometry(ref_mesh=ref_mesh)
        return nothing
    end

    # We delete at the end to avoid deleting nodes that are still being traversed if delete == :nodes
    if delete == :nodes
        MultiScaleTreeGraph.delete_nodes!(mtg, symbol=from, child_link_fun=child_link_fun)
    elseif delete == :geometry
        MultiScaleTreeGraph.traverse!(mtg, symbol=from) do node_from
            pop!(node_from, :geometry)
        end
    end

    return nothing
end