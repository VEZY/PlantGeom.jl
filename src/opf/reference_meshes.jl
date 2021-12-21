"""
    get_ref_meshes(mtg)

Get all reference meshes from an mtg, usually from an OPF.

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)

using MeshViz, GLMakie
viz(meshes)
meshes.meshes[0].material
```
"""
function get_ref_meshes(mtg)

    if !isroot(mtg)
        @warn "Node is not the root node, using `get_root(mtg)`."
        x = get_root(mtg)
    else
        x = mtg
    end

    return x.attributes[:ref_meshes]
end

"""
    parse_ref_meshes(mtg)

Parse the reference meshes of an OPF into RefMeshes.
"""
function parse_ref_meshes(x)

    meshes = RefMeshes(Dict{Int,RefMesh}())
    meshBDD = meshBDD_to_meshes(x[:meshBDD])

    for (id, value) in x[:shapeBDD]
        push!(
            meshes.meshes,
            id => RefMesh(
                value["name"],
                meshBDD[value["meshIndex"]]["normals"],
                haskey(meshBDD[value["meshIndex"]], "textureCoords") ?
                meshBDD[value["meshIndex"]]["textureCoords"] : nothing,
                materialBDD_to_material(x[:materialBDD][value["materialIndex"]]),
                meshBDD[value["meshIndex"]]["mesh"]
            )
        )
    end

    return meshes
end


"""
    meshBDD_to_meshes(x)

# Examples

```julia
using MultiScaleTreeGraph
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
meshBDD_to_meshes(opf.attributes[:meshBDD])
```
"""
function meshBDD_to_meshes(x)
    meshes = Dict{Int,Any}()

    for (key, value) in x
        mesh = Dict()
        mesh_points = pop!(value, "points")
        mesh_faces = pop!(value, "faces")

        points3d = Point3[mesh_points[p:(p+2)] for p = 1:3:length(mesh_points)]
        faces3d = [connect((mesh_faces[p:(p+2)]...,), Ngon) for p = 1:3:length(mesh_faces)]

        push!(mesh, "mesh" => SimpleMesh(points3d, faces3d))
        merge!(mesh, value)

        push!(meshes, key => mesh)
    end

    return meshes
end


"""
Parse a material in opf format to a [`material`](@ref)
"""
function materialBDD_to_material(x)
    Material(
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
    meshes_vec = Dict{Int,SimpleMesh}()
    translation_vec = [0.0, 0.0, 0.0]

    for (key, value) in meshes.meshes

        translated_vertices = [i + Vec(translation_vec...) for i in vertices(value.mesh)]

        push!(meshes_vec, key => SimpleMesh(translated_vertices, topology(value.mesh)))

        # Maximum X coordinates of the newly translated mesh:
        xmax = maximum([coordinates(i)[1] for i in translated_vertices])
        # Update the translation for the next mesh to begin at xmax*1.1 from the last one
        translation_vec[1] = xmax * 1.1
    end

    return meshes_vec
end



"""
    get_ref_meshes_color(meshes::RefMeshes)

Get the reference meshes colors (only the diffuse part for now).

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)
PlantGeom.get_ref_meshes_color(meshes)
```
"""
function get_ref_meshes_color(meshes::RefMeshes)
    mesh_cols = Dict{Int,RGBA{Float64}}()

    for (key, value) in meshes.meshes
        push!(mesh_cols, key => value.material.diffuse)
    end

    return mesh_cols
end
