"""
    refmesh_to_mesh(node)

Compute a node mesh based on the reference mesh, the transformation matrix and the tapering.

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
opf = read_opf(file)

node = opf[1][1][1]

new_mesh = refmesh_to_mesh(node)

using GLMakie
plantviz(new_mesh)
```
"""
refmesh_to_mesh

"""
    geometry_to_mesh(geom)

Materialize a geometry object into a concrete mesh.

This is an internal extension point used by scene merging and rendering. The
default PlantGeom method supports [`Geometry`](@ref). Additional geometry
sources can provide their own method without changing the rendering API.
"""
function geometry_to_mesh(geom)
    error("No `geometry_to_mesh` method is defined for geometry type $(typeof(geom)).")
end

function geometry_to_mesh(geom::Geometry)
    ref_mesh = geom.ref_mesh.mesh

    if geom.ref_mesh.taper
        ref_mesh = taper(ref_mesh, geom.dUp, geom.dDwn)
    end

    apply_transformation(geom.transformation, ref_mesh)
end

function refmesh_to_mesh(node)
    if has_geometry(node)
        return geometry_to_mesh(node[:geometry])
    else
        return nothing
    end
end

function apply_transformation(transformation::Transformation, ref_mesh)
    apply_transformation_to_mesh(transformation, ref_mesh)
end

function refmesh_to_mesh!(node)
    error("refmesh_to_mesh! is deprecated, use `refmesh_to_mesh` instead (non-mutating).")
end
