"""
    get_ref_meshes(mtg)

Get all reference meshes from an mtg, usually from an OPF.

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)

using MeshViz
viz(meshes[0]["mesh"])
viz(meshes)
meshes.meshes
```
"""
function get_ref_meshes(mtg)

    x = mtg.attributes

    @assert isroot(mtg) "Node is not the root node."
    @assert haskey(x, :meshBDD) "MTG does not have mesh info (`:meshBDD`)."
    @assert haskey(x, :shapeBDD) "MTG does not have mesh info (`:shapeBDD`)."
    @assert haskey(x, :materialBDD) "MTG does not have mesh info (`:materialBDD`)."

    meshes = RefMeshes(Dict{Int,RefMesh}())
    meshBDD = meshBDD_to_meshes(x[:meshBDD])

    for (id, value) in x[:shapeBDD]
        push!(
            meshes.meshes,
            id => RefMesh(
                value["name"],
                meshBDD[value["meshIndex"]]["normals"],
                meshBDD[value["meshIndex"]]["textureCoords"],
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
        x["emission"],
        x["ambient"],
        x["diffuse"],
        x["specular"],
        x["shininess"]
    )
end


"""
    align_ref_meshes(meshes::RefMeshes)

Align all reference meshes along the X axis. Used for visualisation only.
"""
function align_ref_meshes(meshes::RefMeshes)
    meshes_vec = SimpleMesh[]
    translation_vec = [0.0, 0.0, 0.0]

    for (key, value) in meshes.meshes

        translated_vertices = [i + Vec(translation_vec...) for i in vertices(value.mesh)]

        push!(meshes_vec, SimpleMesh(translated_vertices, topology(value.mesh)))

        # Maximum X coordinates of the newly translated mesh:
        xmax = maximum([coordinates(i)[1] for i in translated_vertices])
        # Update the translation for the next mesh to begin at xmax*1.1 from the last one
        translation_vec[1] = xmax * 1.1
    end

    return meshes_vec
end



"""
Find each mesh color.

# Notes
`meshes` is typically the output from [`meshes_from_topology`].

# Exemples
opf= read_opf("simple_OPF_shapes.opf")
mesh_data= meshes_from_topology(opf)
shapes= extract_opf_shapes(opf)
materials= extract_opf_materials(opf)
cols= meshes_color(opf,mesh_data)
mesh(merge_meshes(mesh_data["mesh"]), color= cols)
"""
function meshes_color(opf, meshes::Dict{String,Dict} = meshes_from_topology(opf))

    mesh_ids = collect(keys(meshes["mesh"]))
    materials = extract_opf_materials(opf)

    # n_triangles= sum([length(i.second.faces) for i in meshes["mesh"]])
    n_triangles = Dict{Int32,Int32}()
    for i in meshes["mesh"]
        push!(n_triangles, i.first => length(i.second.vertices))
    end
    n_triangles_tot = sum(values(n_triangles))
    prev_max = [0]
    # mesh_color= Dict{Int32, RGBA{Float64}}() # To get only the color per mesh ID
    triangle_color = Array{RGBA{Float64}}(undef, n_triangles_tot)

    for i = 1:length(mesh_ids)
        material_id = meshes["attributes"][mesh_ids[i]]["materialIndex"]
        col = RGBA(materials[material_id].diffuse...)
        # push!(mesh_color, mesh_ids[i] => col)
        for j in ((1:n_triangles[mesh_ids[i]]) .+ prev_max[1])
            triangle_color[j] = col
        end
        prev_max[1] += n_triangles[mesh_ids[i]]
    end

    return triangle_color
end


plottype(::RefMeshes) = Viz{<:Tuple{RefMeshes}}

"""
using MultiScaleTreeGraph, PlantGeom, WGLMakie

file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)

viz(meshes)
"""
function plot!(plot::Viz{<:Tuple{RefMeshes}})
    # function plot!(plot::MakieCore.Combined{MeshViz.viz,S} where {S<:Tuple{PlantGeom.RefMeshes}})
    # Mesh list:
    p = align_ref_meshes(plot[:object][])

    # Plot options:
    color = plot[:color][]
    facetcolor = plot[:facetcolor][]
    showfacets = plot[:showfacets][]
    colormap = plot[:colormap][]

    for i = 1:length(p)
        viz!(plot, p[i], color = color, facetcolor = facetcolor, showfacets = showfacets, colormap = colormap)
    end
end
