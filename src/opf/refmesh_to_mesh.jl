"""
    refmesh_to_mesh!(node)
    refmesh_to_mesh(node)

Compute a node mesh based on the reference mesh, the transformation matrix and the tapering.
The mutating version adds the new mesh to the `mesh` field of the geometry attribute of the
node.

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)

node = opf[1][1][1]

new_mesh = refmesh_to_mesh(node)

using MeshViz, GLMakie
viz(new_mesh)
```
"""
refmesh_to_mesh!, refmesh_to_mesh

function refmesh_to_mesh(node)
    if node[:geometry] !== nothing

        ref_mesh = node[:geometry].ref_mesh.mesh

        # Get the reference mesh and taper it in z and y (the principal axis is following x already):
        if node[:geometry].ref_mesh.taper # Taper only if enableScale="true" in the OPF: taper == true
            ref_mesh = taper(ref_mesh, node[:geometry].dUp, node[:geometry].dDwn)
        end

        scaled_mesh = Array{Point3}(undef, nvertices(ref_mesh))
        for (i, p) in enumerate(ref_mesh.points)
            scaled_mesh[i] = Point3((node[:geometry].transformation_matrix*vcat(p.coords, 1.0))[1:3])
        end

        return SimpleMesh(scaled_mesh, ref_mesh.topology)
    else
        return nothing
    end
end


function refmesh_to_mesh!(node)
    if node[:geometry] !== nothing

        ref_mesh = node[:geometry].ref_mesh.mesh

        # Get the reference mesh and taper it in z and y (the principal axis is following x already):
        if node[:geometry].ref_mesh.taper # Taper only if enableScale="true" in the OPF: taper == true
            ref_mesh = taper(ref_mesh, node[:geometry].dUp, node[:geometry].dDwn)
        end

        scaled_mesh = Array{Point3}(undef, nvertices(ref_mesh))
        for (i, p) in enumerate(ref_mesh.points)
            scaled_mesh[i] = Point3((node[:geometry].transformation_matrix*vcat(p.coords, 1.0))[1:3])
        end

        node[:geometry].mesh = SimpleMesh(scaled_mesh, ref_mesh.topology)
        return node[:geometry].mesh
    else
        return nothing
    end
end
