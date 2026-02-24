"""
    transform_mesh!(node::Node, transformation)

Add a new transformation to the node geometry `transformation` field.
The transformation is composed with the previous transformation if any.

`transformation` must be a `CoordinateTransformations.Transformation`.
"""
function transform_mesh!(node::MultiScaleTreeGraph.Node, transformation::Transformation)
    if has_geometry(node)
        node[:geometry].transformation = transformation ∘ node[:geometry].transformation
    end
end

function apply(t::Transformation, x::RefMesh)
    RefMesh(x.name, apply_transformation_to_mesh(t, x.mesh), x.normals, x.texture_coords, x.material, x.taper)
end
