"""
    get_ref_meshes(mtg)

Get all reference meshes from an mtg, usually from an OPF.
"""
function get_ref_meshes(mtg)
    if !isroot(mtg)
        @warn "Node is not the root node, using `get_root(mtg)`."
        x = get_root(mtg)
    else
        x = mtg
    end

    ref_meshes = OrderedCollections.OrderedSet{RefMesh}()
    traverse!(x) do node
        if has_geometry(node) && isa(node[:geometry], Geometry)
            push!(ref_meshes, node[:geometry].ref_mesh)
        end
    end
    return collect(ref_meshes)
end

"""
    get_ref_mesh_name(node)

Get the name of the reference mesh used for the current node.
"""
function get_ref_mesh_name(node::MultiScaleTreeGraph.Node)
    return get_ref_mesh_name(node[:geometry])
end

function get_ref_mesh_name(geom::Geometry)
    return geom.ref_mesh.name
end

function get_ref_mesh_name(geom)
    return string(nameof(typeof(geom)))
end

"""
    parse_ref_meshes(mtg)

Parse the reference meshes of an OPF into RefMeshes.
"""
function parse_ref_meshes(x)
    meshes = Dict{Int,RefMesh}()
    meshBDD = x[:meshBDD]
    materialBDD = x[:materialBDD]
    fallback_material = if isempty(materialBDD)
        _default_phong_material()
    else
        materialBDD[first(sort(collect(keys(materialBDD))))]
    end

    for (id, value) in x[:shapeBDD]
        material_index = value["materialIndex"]
        material = get(materialBDD, material_index, fallback_material)
        push!(
            meshes,
            id => RefMesh(
                string(value["name"]),
                meshBDD[value["meshIndex"]].mesh,
                meshBDD[value["meshIndex"]].normals,
                meshBDD[value["meshIndex"]].textureCoords,
                material,
                meshBDD[value["meshIndex"]].enableScale
            )
        )
    end

    refmeshes = RefMesh[]
    for i in sort(collect(keys(meshes)))
        push!(refmeshes, meshes[i])
    end

    return refmeshes
end

"""
    meshBDD_to_meshes(x)
"""
function meshBDD_to_meshes(x)
    meshes = Dict{Int,Any}()

    for (key, value) in x
        mesh = Dict()
        mesh_points = pop!(value, "points")
        mesh_faces = pop!(value, "faces")

        points3d = [point3(mesh_points[p], mesh_points[p+1], mesh_points[p+2]) for p in 1:3:length(mesh_points)]
        faces3d = [face3(mesh_faces[p], mesh_faces[p+1], mesh_faces[p+2]) for p in 1:3:length(mesh_faces)]

        push!(mesh, "mesh" => _mesh(points3d, faces3d))
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
    align_ref_meshes(meshes::Vector{<:RefMesh})

Align all reference meshes along the X axis. Used for visualisation only.
"""
function align_ref_meshes(meshes::Vector{T}) where {T<:RefMesh}
    meshes_dict = Dict{String,Any}()
    x_offset = 0.0

    for i in meshes
        trans = Translation(x_offset, 0.0, 0.0)
        mesh_ = apply_transformation_to_mesh(trans, i.mesh)
        push!(meshes_dict, i.name => mesh_)

        xmax_ = maximum(p -> p[1], _vertices(mesh_))
        x_offset = xmax_ * 1.1
    end

    return meshes_dict
end

align_ref_meshes(refmesh::T) where {T<:RefMesh} = Dict(refmesh.name => refmesh.mesh)

"""
    get_ref_meshes_color(meshes::Vector{<:RefMesh})

Get the reference meshes colors (only the diffuse part for now).
"""
function get_ref_meshes_color(meshes::Vector{T}) where {T<:RefMesh}
    Dict(i.name => material_single_color(i.material) for i in meshes)
end

get_ref_meshes_color(refmesh::T) where {T<:RefMesh} = Dict(refmesh.name => material_single_color(refmesh.material))

function material_single_color(x::Phong)
    x.diffuse
end

function material_single_color(x::Colorant)
    x
end

@inline function geometry_display_color(node::MultiScaleTreeGraph.Node)
    geometry_display_color(node[:geometry])
end

@inline function geometry_display_color(geom::Geometry)
    material_single_color(geom.ref_mesh.material)
end

@inline function geometry_display_color(::Any)
    RGB(220 / 255, 220 / 255, 220 / 255)
end
