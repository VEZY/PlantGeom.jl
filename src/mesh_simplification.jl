"""
    simplify_geometry(mtg; from, into, delete=true, child_link_fun=new_child_link)

Simplifies the geometry of a MultiScaleTreeGraph (MTG) by merging low-scale geometries into an higher-scale geometry.

# Arguments

- `mtg`: The MultiScaleTreeGraph to process.
- `from`: The string for the type of nodes to simplify, this is the lower scale meshes that need to be merged. Can be a string or a vector of strings, *e.g.* ["Petiole", "Rachis"].
- `into`: The string for the type of nodes to merge into. Must be a single string, *e.g.* "Leaf".
- `delete`: A boolean indicating whether to delete the nodes that will be merged from the MTG after processing. Defaults to `true`.
- `child_link_fun`: A function that takes a parent node targeted for deletion and returns the new links for their children. Required if `delete` is `true`.

# Returns

- Nothing. The function modifies the `mtg` in place.

# Notes

If no geometry is found in the children nodes of type `from`, an informational message is logged.
"""
function simplify_geometry(mtg; from, into, delete=true, child_link_fun=new_child_link)
    @assert into isa AbstractString """`into` must be a single string, e.g. "Leaf"."""
    delete && @assert child_link_fun isa Function """`child_link_fun` must be a function that takes a parent node targeted for deletion, and returns the new links for their children."""

    # Traverse the tree and simplify the geometry
    MultiScaleTreeGraph.traverse!(mtg, symbol=into) do node
        meshes_vec = MultiScaleTreeGraph.traverse(node, filter_fun=node -> haskey(node, :geometry), type=Meshes.SimpleMesh, symbol=from) do node
            refmesh_to_mesh(node)
        end
        if isempty(meshes_vec)
            # First, test if we find any children nodes of type `from`:
            no_nodes_as_descendants = MultiScaleTreeGraph.descendants(node, symbol=from) |> isempty
            if no_nodes_as_descendants
                @info "No children nodes of type $from found in node $node"
            else
                @info "No geometry found in children nodes $from for node $node"
            end
        end
        delete && MultiScaleTreeGraph.delete_nodes!(node, symbol=from, child_link_fun=child_link_fun)
        # Build a new reference mesh out of the children nodes
        ref_mesh = RefMesh(string(into, MultiScaleTreeGraph.node_id(node)), reduce(merge, meshes_vec))
        node.geometry = Geometry(ref_mesh=ref_mesh)
        return nothing
    end
end