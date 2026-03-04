@inline geometry_ref_mesh(geom::Geometry) = geom.ref_mesh
@inline geometry_ref_mesh(geom::PointMappedGeometry) = geom.ref_mesh
@inline geometry_ref_mesh(::Any) = nothing

"""
    get_ref_mesh_name(node)

Get the reference-mesh-like name used by the current node geometry source.
"""
function get_ref_mesh_name(node::MultiScaleTreeGraph.Node)
    return get_ref_mesh_name(node[:geometry])
end

function get_ref_mesh_name(geom::Geometry)
    return geom.ref_mesh.name
end

function get_ref_mesh_name(geom::PointMappedGeometry)
    return geom.ref_mesh.name
end

function get_ref_mesh_name(::ExtrudedTubeGeometry)
    return "ExtrudedTube"
end

function get_ref_mesh_name(geom)
    return string(nameof(typeof(geom)))
end

@inline function geometry_display_color(node::MultiScaleTreeGraph.Node)
    geometry_display_color(node[:geometry])
end

@inline function geometry_display_color(geom::Geometry)
    material_single_color(geom.ref_mesh.material)
end

@inline function geometry_display_color(geom::PointMappedGeometry)
    material_single_color(geom.ref_mesh.material)
end

@inline function geometry_display_color(geom::ExtrudedTubeGeometry)
    material_single_color(geom.material)
end

@inline function geometry_display_color(::Any)
    RGB(220 / 255, 220 / 255, 220 / 255)
end
