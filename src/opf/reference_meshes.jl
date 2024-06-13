"""
    get_ref_meshes(mtg)

Get all reference meshes from an mtg, usually from an OPF.

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)

using GLMakie
viz(meshes)
```
"""
function get_ref_meshes(mtg)

    if !isroot(mtg)
        @warn "Node is not the root node, using `get_root(mtg)`."
        x = get_root(mtg)
    else
        x = mtg
    end

    return x[:ref_meshes]
end

function get_ref_mesh_index!(node, ref_meshes=get_ref_meshes(node))

    # If the reference node mesh is unknown, get it:
    if node[:geometry].ref_mesh_index === nothing
        node[:geometry].ref_mesh_index =
            findfirst(x -> x === node[:geometry].ref_mesh, ref_meshes.meshes)
    end

    return node[:geometry].ref_mesh_index
end

function get_ref_mesh_index(node, ref_meshes=get_ref_meshes(node))
    # If the reference node mesh is unknown, get it:
    if node[:geometry].ref_mesh_index === nothing
        return findfirst(x -> x === node[:geometry].ref_mesh, ref_meshes.meshes)
    end

    return node[:geometry].ref_mesh_index
end

"""
    get_ref_mesh_index!(node, ref_meshes = get_ref_meshes(node))
    get_ref_mesh_index(node, ref_meshes = get_ref_meshes(node))

Get the index of the reference mesh used in the current node.

# Notes

Please use the `ref_meshes` argument preferably as not giving it make the function visit the
root node each time otherwise, and it can become a limitation when traversing a big MTG.
"""
get_ref_mesh_index!, get_ref_mesh_index


"""
    parse_ref_meshes(mtg)

Parse the reference meshes of an OPF into RefMeshes.
"""
function parse_ref_meshes(x)
    meshes = Dict{Int,RefMesh}()
    meshBDD = x[:meshBDD]

    for (id, value) in x[:shapeBDD]
        push!(
            meshes,
            id => RefMesh(
                string(value["name"]),
                meshBDD[value["meshIndex"]].mesh,
                meshBDD[value["meshIndex"]].normals,
                meshBDD[value["meshIndex"]].textureCoords,
                x[:materialBDD][value["materialIndex"]],
                meshBDD[value["meshIndex"]].enableScale
            )
        )
    end

    # We create RefMeshes just now in case they were not sorted in the opf file
    refmeshes = RefMeshes(RefMesh[])
    #! Do we really need to sort them? If not, we directly build it above instead of using
    #! an intermediary Dict
    for i in sort(collect(keys(meshes)))
        push!(refmeshes.meshes, meshes[i])
    end

    return refmeshes
end


"""
    meshBDD_to_meshes(x)

# Examples

```julia
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.opf")
opf = read_opf(file)
meshBDD_to_meshes(opf[:meshBDD])
```
"""
function meshBDD_to_meshes(x)
    meshes = Dict{Int,Any}()

    for (key, value) in x
        mesh = Dict()
        mesh_points = pop!(value, "points")
        mesh_faces = pop!(value, "faces")

        points3d = Meshes.Point[mesh_points[p:(p+2)] for p = 1:3:length(mesh_points)]
        faces3d = [Meshes.connect((mesh_faces[p:(p+2)]...,), Meshes.Ngon) for p = 1:3:length(mesh_faces)]

        push!(mesh, "mesh" => Meshes.SimpleMesh(points3d, faces3d))
        merge!(mesh, value)

        push!(meshes, key => mesh)
    end

    return meshes
end


"""
Parse a material in opf format to a [`Phong`](@ref) material.
"""
function materialBDD_to_material(x)
    Phong(
        RGBA(x["emission"]...),
        RGBA(x["ambient"]...),
        RGBA(x["diffuse"]...),
        RGBA(x["specular"]...),
        x["shininess"]
    )
end


"""
    align_ref_meshes(meshes::RefMeshes)

Align all reference meshes along the X axis. Used for visualisation only.
"""
function align_ref_meshes(meshes::RefMeshes)
    meshes_vec = Meshes.SimpleMesh[]
    trans = Translate(0.0, 0.0, 0.0)

    for i in meshes.meshes
        push!(meshes_vec, trans(i.mesh))
        # Maximum X coordinates of the newly translated mesh:
        xmax_ = Meshes.coords(maximum(Meshes.boundingbox(i.mesh))).x

        # Update the translation for the next mesh to begin at xmax*1.1 from the last one
        trans = Translate(xmax_.val * 1.1, 0.0, 0.0)
    end

    return meshes_vec
end



"""
    get_ref_meshes_color(meshes::RefMeshes)

Get the reference meshes colors (only the diffuse part for now).

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)
PlantGeom.get_ref_meshes_color(meshes)
```
"""
function get_ref_meshes_color(meshes::RefMeshes)
    [material_single_color(i.material) for i in meshes.meshes]
end

function material_single_color(x::Phong)
    x.diffuse
end

function material_single_color(x::Colorant)
    x
end
