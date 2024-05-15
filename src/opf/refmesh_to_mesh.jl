"""
    refmesh_to_mesh!(node)
    refmesh_to_mesh(node)

Compute a node mesh based on the reference mesh, the transformation matrix and the tapering.
The mutating version adds the new mesh to the `mesh` field of the geometry attribute of the
node.

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
opf = read_opf(file)

node = opf[1][1][1]

new_mesh = refmesh_to_mesh(node)

using GLMakie
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

        return apply_transformation(node[:geometry].transformation, ref_mesh)
    else
        return nothing
    end
end

function apply_transformation(transformation, ref_mesh)
    Meshes.SimpleMesh([transformation(p) for p in ref_mesh.vertices], Meshes.topology(ref_mesh))
end

function refmesh_to_mesh!(node)
    if node[:geometry] !== nothing

        ref_mesh = node[:geometry].ref_mesh.mesh

        # Get the reference mesh and taper it in z and y (the principal axis is following x already):
        if node[:geometry].ref_mesh.taper # Taper only if enableScale="true" in the OPF: taper == true
            ref_mesh = taper(ref_mesh, node[:geometry].dUp, node[:geometry].dDwn)
        end

        scaled_mesh = Array{Meshes.Point3}(undef, Meshes.nvertices(ref_mesh))
        for (i, p) in enumerate(ref_mesh.vertices)
            scaled_mesh[i] = Meshes.Point3(node[:geometry].transformation(p.coords))
        end

        node[:geometry].mesh = Meshes.SimpleMesh(scaled_mesh, Meshes.topology(ref_mesh))
        return node[:geometry].mesh
    else
        return nothing
    end
end
