"""
    transform_mesh!(node::Node, transformation)

Add a new transformation to the node geometry `transformation` field.
The transformation is composed with the previous transformation if any.

`transformation` must be a `CoordinateTransformations.Transformation`.
"""
function transform_mesh!(node::MultiScaleTreeGraph.Node, transformation::Transformation)
    if has_geometry(node)
        geom = node[:geometry]
        if geom isa Geometry
            node[:geometry] = Geometry(
                ref_mesh=geom.ref_mesh,
                transformation=transformation ∘ geom.transformation,
                dUp=geom.dUp,
                dDwn=geom.dDwn,
            )
        elseif geom isa PointMappedGeometry
            node[:geometry] = PointMappedGeometry(
                geom.ref_mesh,
                geom.point_map;
                params=geom.params,
                transformation=transformation ∘ geom.transformation,
            )
        end
    end
end

function apply(t::Transformation, x::RefMesh)
    RefMesh(x.name, apply_transformation_to_mesh(t, x.mesh), x.normals, x.texture_coords, x.material, x.taper)
end
