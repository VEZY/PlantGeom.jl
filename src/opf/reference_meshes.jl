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
        if has_geometry(node)
            ref_mesh = geometry_ref_mesh(node[:geometry])
            !isnothing(ref_mesh) && push!(ref_meshes, ref_mesh)
        end
    end
    return collect(ref_meshes)
end

"""
    parse_ref_meshes(opf_attr)

Parse the reference meshes from OPF attributes into a dictionary.

# Arguments
- `opf_attr::Dict`: Dictionary containing OPF attributes including `:meshBDD`, `:materialBDD`, and `:shapeBDD`

# Returns
- `Dict{Int, RefMesh}`: A dictionary mapping shape IDs to RefMesh objects

# Notes
- The returned dictionary uses the actual shape IDs from the OPF file as keys
- This differs from the previous implementation which returned an array with 1-based indexing
- Shape IDs, mesh indices, and material indices are used as-is from the OPF file (0-based)
"""
function parse_ref_meshes(x)
    shapeBDD = x[:shapeBDD]
    meshes = Dict{Int,RefMesh}()
    sizehint!(meshes, length(shapeBDD))
    meshBDD = x[:meshBDD]
    materialBDD = x[:materialBDD]
    fallback_material = if isempty(materialBDD)
        _default_phong_material()
    else
        first(values(materialBDD))
    end

    for (id, shape) in shapeBDD
        mesh_entry = meshBDD[shape.mesh_index]
        material = get(materialBDD, shape.material_index, fallback_material)
        meshes[id] = RefMesh(
            shape.name,
            mesh_entry.mesh,
            mesh_entry.normals,
            mesh_entry.textureCoords,
            material,
            mesh_entry.enableScale,
        )
    end

    # Return the dictionary with shape IDs as keys, not an array
    return meshes
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
    get_ref_meshes_color(meshes)

Get the reference meshes colors (only the diffuse part for now).

# Arguments
- `meshes::Dict{Int, RefMesh}`: Dictionary of reference meshes as returned by `parse_ref_meshes`
- `meshes::AbstractVector{<:RefMesh}`: Vector/list of reference meshes (legacy and plotting workflows)

# Returns
- `Dict{String, Colorant}`: Dictionary mapping mesh names to their diffuse colors

# Notes
- Only the diffuse component of the material is used for the color
- Dictionary input preserves OPF shape-ID keyed workflows
"""
function get_ref_meshes_color(meshes::Dict{Int,T}) where {T<:RefMesh}
    Dict(i.name => material_single_color(i.material) for i in values(meshes))
end

function get_ref_meshes_color(meshes::AbstractVector{T}) where {T<:RefMesh}
    Dict(i.name => material_single_color(i.material) for i in meshes)
end

get_ref_meshes_color(refmesh::T) where {T<:RefMesh} = Dict(refmesh.name => material_single_color(refmesh.material))

function material_single_color(x::Phong)
    x.diffuse
end

function material_single_color(x::Colorant)
    x
end
