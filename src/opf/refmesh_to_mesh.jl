"""
    refmesh_to_mesh(node, ref_meshes)

Compute a node mesh based on the reference mesh, the transformation matrix and the tapering.

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)

node = opf[1][1][1]

new_mesh = refmesh_to_mesh(node, get_ref_meshes(opf))

using MeshViz, GLMakie
viz(new_mesh)
```
"""
function refmesh_to_mesh(node, ref_meshes)
    if node[:geometry] !== nothing && haskey(node[:geometry], :shapeIndex)

        if haskey(node[:geometry], :mat)
            # Add w to the transformation matrix:
            m = node[:geometry][:mat]
        else
            m = I # identity matrix from LinearAlgebra package (lazy)
        end

        ref_mesh_info = ref_meshes.meshes[node[:geometry][:shapeIndex]]
        ref_mesh = ref_mesh_info.mesh

        # Get the reference mesh and taper it in z and y (the principal axis is following x already):
        ref_mesh_scaled = taper(ref_mesh, node[:geometry][:dUp], node[:geometry][:dDwn])

        scaled_mesh = Array{Point3}(undef, nvertices(ref_mesh_scaled))
        for (i, p) in enumerate(ref_mesh_scaled.points)
            scaled_mesh[i] = Point3((m*vcat(p.coords, 1.0))[1:3])
        end

        return SimpleMesh(scaled_mesh, ref_mesh_scaled.topology)
    else
        return nothing
    end
end
