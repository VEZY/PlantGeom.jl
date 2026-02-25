"""
    read_opf(file; attr_type = Dict, mtg_type = MutableNodeMTG)

Read an OPF file, and returns an MTG.

# Arguments

- `file::String`: The path to the opf file.
- `attr_type::DataType = Dict`: kept for backward compatibility and ignored for
  MultiScaleTreeGraph >= v0.15 (typed columnar attributes backend is always used).
- `mtg_type = MutableNodeMTG`: the type used to hold the mtg encoding for each node (*i.e.*
link, symbol, index, scale). See details section below.
- `read_id::Bool = true`: whether to read the ID from the OPF or recompute it on the fly.
- `max_id::RefValue{Int64}=Ref(1)`: the ID of the first node, if `read_id==false`.

# Details

`attr_type` is ignored with MultiScaleTreeGraph >= v0.15 where the typed
columnar backend is always used.

The `MultiScaleTreeGraph` package provides two types for `mtg_type`, one immutable
(`NodeMTG`), and one mutable (`MutableNodeMTG`). If you're planning on modifying the mtg
encoding of some of your nodes, you should use `MutableNodeMTG`, and if you don't want to modify 
anything, use `NodeMTG` instead as it should be faster.

# Note

See the documentation of the MTG format from the MTG package documentation for further details,
*e.g.* [The MTG concept](https://vezy.github.io/MultiScaleTreeGraph.jl/stable/the_mtg/mtg_concept/).

# Returns

The MTG root node.

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
# file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")
opf = read_opf(file)
```
"""
function read_opf(
    file;
    attr_type=Dict,
    mtg_type=MultiScaleTreeGraph.MutableNodeMTG,
    read_id=true,
    max_id=Ref(1)
)

    doc = readxml(file)
    xroot = root(doc)

    if xroot.name != "opf"
        error("The file is not an OPF")
    end

    if xroot["version"] != "2.0"
        error("Cannot read OPF files version other than 2.0")
    end

    editable = parse(Bool, xroot["editable"])

    opf_attr = Dict{Symbol,Any}()
    # node = elements(xroot)[end]
    for node in eachelement(xroot)
        if node.name == "meshBDD"
            push!(opf_attr, :meshBDD => parse_meshBDD!(node; file=file))
        end

        if node.name == "materialBDD"
            push!(
                opf_attr,
                :materialBDD => parse_materialBDD!(node; file=file)
            )
        end

        if node.name == "shapeBDD"
            shapeBDD = parse_opf_elements!(
                node,
                [String, Int64, Int64]
            )

            # Increment index by 1 because Julia is 1-based indexing (OPF is 0-based):
            for (key, value) in shapeBDD
                value["materialIndex"] += 1
                value["meshIndex"] += 1
            end

            push!(opf_attr, :shapeBDD => shapeBDD)
        end

        if node.name == "attributeBDD"
            push!(opf_attr, :attributeBDD => parse_opf_attributeBDD!(node))
        end

        if node.name == "topology"
            ref_meshes = parse_ref_meshes(opf_attr)
            mtg = parse_opf_topology!(
                node,
                nothing,
                get_attr_type(opf_attr[:attributeBDD]),
                attr_type,
                mtg_type,
                ref_meshes,
                read_id,
                max_id
            )

            mtg[:ref_meshes] = ref_meshes
            return mtg
        end
    end
end

"""
Parse an array of values from the OPF into a Julia array (Arrays in OPFs
are not following XML recommendations)
"""
function parse_opf_array(elem, type=Float64)
    if type == String
        strip(elem)
    else
        parsed = map(split(elem)) do e
            e == "NA" && return nothing
            isempty(e) && return nothing
            parsed_e = tryparse(type, e)
            isnothing(parsed_e) && @warn "Could not parse attribute value '$e' in OPF as type $type (type defined in `attributeBDD`)."
            return parsed_e
        end
        if length(parsed) == 1
            return parsed[1]
        else
            return parsed
        end
    end
end

@inline function _opf_triangulate_face_indices(ids::AbstractVector{Int})
    out = Face3[]
    length(ids) < 3 && return out
    if length(ids) == 3
        push!(out, face3(ids[1], ids[2], ids[3]))
        return out
    end
    for i in 2:(length(ids)-1)
        push!(out, face3(ids[1], ids[i], ids[i+1]))
    end
    out
end

function _opf_parse_faces(elem, file::AbstractString, mesh_name::AbstractString)
    faces3d = Face3[]
    face_nodes = [face_node for face_node in eachelement(elem) if face_node.name == "face"]

    if isempty(face_nodes)
        content = parse_opf_array(elem.content, Int)
        flat_ids = content isa Integer ? Int[content] : Int[content...]
        length(flat_ids) % 3 == 0 || error("Invalid flat face list in OPF mesh '$mesh_name' from file $file")
        for p in 1:3:length(flat_ids)
            push!(faces3d, face3(flat_ids[p] + 1, flat_ids[p+1] + 1, flat_ids[p+2] + 1))
        end
        return faces3d
    end

    for face_node in face_nodes
        ids = Int[parse(Int, m.match) + 1 for m in eachmatch(r"-?\d+", face_node.content)]
        length(ids) >= 3 || error("Invalid face in OPF mesh '$mesh_name' from file $file")
        append!(faces3d, _opf_triangulate_face_indices(ids))
    end
    return faces3d
end

function _default_phong_material()
    Phong(
        RGBA(0.0, 0.0, 0.0, 1.0),
        RGBA(0.2, 0.2, 0.2, 1.0),
        RGBA(0.8, 0.8, 0.8, 1.0),
        RGBA(0.0, 0.0, 0.0, 1.0),
        0.0
    )
end



# struct TestMesh{N<:AbstractVector,T<:AbstractVector}
#     points::N
#     faces::T
# end

struct OPFmesh{M<:GeometryBasics.AbstractMesh{3},N<:AbstractVector,T<:Union{AbstractVector,Nothing}}
    name::String
    enableScale::Bool
    mesh::M
    normals::N
    textureCoords::T # texture coordinates (length = length(points) * 2/3, or Nothing)
end

"""
    parse_meshBDD!(node; file=\"\")

Parse the meshBDD using [`parse_opf_array`](@ref).

Supports both flat `<faces>` arrays and nested `<face>` elements. Polygon faces with
more than three vertices are triangulated with a fan strategy.
"""
function parse_meshBDD!(node; file="")
    # MeshBDD:
    meshes = Dict{Int,OPFmesh}()
    # m = elements(node)[1]
    # length(parse_opf_array(elements(m)[3].content))
    # content = parse_opf_array(elements(m)[3].content)
    for m in eachelement(node)
        m.name != "mesh" ? @warn("Unknown node element in meshBDD: $(m.name)") : nothing
        mesh = Dict{String,Any}()
        mesh["name"] = m["name"]
        mesh["enableScale"] = parse(Bool, m["enableScale"])

        for i in eachelement(m)
            if i.name == "faces"
                faces3d = _opf_parse_faces(i, file, mesh["name"])
                push!(mesh, "faces" => faces3d)
            elseif i.name == "textureCoords"
                content = parse_opf_array(i.content) ./ 100
                content = [
                    GeometryBasics.Point{2,Float64}(content[p], content[p+1]) for p in 1:2:length(content)
                ]
                push!(mesh, "textureCoords" => content)
            elseif i.name == "normals"
                content = parse_opf_array(i.content)
                content = [
                    vec3(content[p], content[p+1], content[p+2]) for p in 1:3:length(content)
                ]
                push!(mesh, "normals" => content)
            elseif i.name == "points"
                content = parse_opf_array(i.content) ./ 100
                content = [
                    point3(content[p], content[p+1], content[p+2]) for p in 1:3:length(content)
                ]
                push!(mesh, i.name => content)
            else
                error("Unknown node element for mesh$(i.Id) in mesh BDD: $(i.name)")
            end
        end

        push!(
            meshes,
            parse(Int, m["Id"]) + 1 =>
                OPFmesh(
                    mesh["name"],
                    mesh["enableScale"],
                    _mesh(mesh["points"], mesh["faces"]),
                    get(mesh, "normals", nothing),
                    get(mesh, "textureCoords", nothing), # using get because sometimes missing
                )
        )
    end

    return meshes
end

"""
    parse_materialBDD!(node; file=nothing)

Parse the materialBDD using [`parse_opf_elements!`](@ref).

When the section is present but empty, a neutral default material is inserted so OPF
files without explicit materials remain readable.
"""
function parse_materialBDD!(node; file=nothing)
    metBDDraw = parse_opf_elements!(
        node,
        [Float64, Float64, Float64, Float64, Float64]
    )
    if isempty(metBDDraw)
        return Dict(1 => _default_phong_material())
    end

    metBDD = Dict{Int,Phong}()
    for (key, value) in metBDDraw
        # key = 1
        # value = metBDDraw[key]
        push!(metBDD, key => materialBDD_to_material(value))
    end

    return metBDD
end

"""
Generic parser for OPF elements.

# Arguments

- `opf::OrderedDict`: the opf Dict (using [XMLDict.xml_dict])
- `elem_types::Array`: the target types of the element (e.g. "[String, Int64]")

# Details

`elem_types` should be of the same length as the number of elements found in each
item of the subchild.
elem_types = [Float64, Float64, Float64, Float64, Float64, Float64]
"""
function parse_opf_elements!(node, elem_types)
    elem_dict = Dict()
    for m in eachelement(node)
        elems_ = Dict()
        for (i, el) in enumerate(elements(m))
            content = parse_opf_array(el.content, elem_types[i])
            if length(content) > 0
                push!(elems_, el.name => content)
            end
        end
        push!(elem_dict, parse(Int, m["Id"]) + 1 => elems_)
    end
    return elem_dict
end

"""
 Parse the opf attributes as a Dict.
"""
function parse_opf_attributeBDD!(node)
    elem_dict = Dict()
    for m in eachelement(node)
        push!(elem_dict, m["name"] => m["class"])
    end
    return elem_dict
end

"""
Get the attributes types in Julia `DataType`.
"""
function get_attr_type(attr)
    attr_Type = Dict{String,DataType}()
    for i in keys(attr)
        if attr[i] in ["Object", "String", "Color", "Image"]
            push!(attr_Type, i => String)
        elseif attr[i] == "Integer"
            push!(attr_Type, i => Int32)
        elseif attr[i] in ["Double", "Metre", "Centimetre", "Millimetre", "10E-5 Metre", "Metre_100"]
            push!(attr_Type, i => Float32)
        elseif attr[i] == "Boolean"
            push!(attr_Type, i => Bool)
        else
            error("Attribute type `$(attr[i])` not recognised in attributeBDD.")
        end
    end
    return attr_Type
end


"""
Parse the geometry element of the OPF.

# Note
The transformation matrix is 3*4.
elem = elem.content
"""
function parse_geometry(elem)
    geom = Dict{Symbol,Union{Int,Float64,SMatrix{3,4}}}()
    for i in eachelement(elem)
        if i.name == "shapeIndex"
            push!(geom, :shapeIndex => parse(Int, i.content) + 1)
        elseif i.name == "mat"
            push!(geom, :mat => SMatrix{3,4}(reshape(parse_opf_array(i.content), 4, 3)'))
        elseif i.name == "dUp"
            push!(geom, :dUp => parse(Float64, i.content))
        elseif i.name == "dDwn"
            push!(geom, :dDwn => parse(Float64, i.content))
        end
    end
    return geom
end


"""

    parse_opf_topology!(node, mtg, features, attr_type, mtg_type, ref_meshes, id_set=Set{Int}())

Parser of the OPF topology.

# Arguments

- `node::ElementNode`: the XML node to parse.
- `mtg::Union{Nothing,Node}`: the parent MTG node.
- `features::Dict`: the features of the OPF.
- `attr_type::DataType`: the type of the attributes to use.
- `mtg_type::DataType`: the type of the MTG to use.
- `ref_meshes::Dict`: the reference meshes.
- `read_id::Bool`: whether to read the ID from the OPF or recompute it on the fly.
- `max_id::RefValue{Int64}=Ref(1)`: the ID of the first node, if `read_id==false`.

# Note

The transformation matrices in `geometry` are 3*4.
"""
function parse_opf_topology!(node, mtg, features, attr_type, mtg_type, ref_meshes, read_id=true, max_id=Ref(1))
    link = :/ # default, for "topology" and "decomp"
    if node.name == "branch"
        link = :+
    elseif node.name == "follow"
        link = :<
    end

    if read_id
        id = parse(Int, node["id"])
    else
        id = max_id[]
        max_id[] += 1
    end

    MTG = mtg_type(
        link,
        node["class"],
        id,
        parse(Int, node["scale"])
    )

    if mtg !== nothing
        node_i = Node(
            id,
            mtg,
            MTG,
            MultiScaleTreeGraph.init_empty_attr()
        )
    else
        # First node:
        node_i = Node(id, MTG, MultiScaleTreeGraph.init_empty_attr())
    end

    # node_i.children
    attrs = Dict{Symbol,Any}()

    # Handle the children, can be attributes of children nodes:
    # elem = elements(node)[1]
    for elem in eachelement(node)
        # If an element is an attribute, add it to the attributes of the Node:
        if elem.name in keys(features)
            push!(attrs, Symbol(elem.name) => parse_opf_array(elem.content, features[elem.name]))
        elseif elem.name == "geometry"

            geom = parse_geometry(elem)

            # Parse the geometry (transformation, reference mesh + index and dUp and dDwn):
            if haskey(geom, :shapeIndex)
                # Rotation + Scaling. No need to decouple them here, but in case we need to
                # in the future, see: https://stackoverflow.com/a/29618569/6947799
                # See also this for decomposition: https://colab.research.google.com/drive/1ImBB-N6P9zlNMCBH9evHD6tjk0dzvy1_

                #! OK what I could do is use my own transformation function that adds w (=1)
                #! to the Point when transforming it with the 4x4 matrix?

                A = SMatrix{3,3,Float64}(@view(geom[:mat][1:3, 1:3]))
                t = SVector{3,Float64}((@view(geom[:mat][1:3, 4])) ./ 100)
                transformation = AffineMap(A, t)
                # NB: We read an homogeneous transformation matrix from the OPF, but we work
                # with cartesian coordinates in PlantGeom by design. So we deconstruct our
                # homogeneous matrix into the two corresponding rotation and translation
                # matrices and create a single affine transform.

                push!(
                    attrs,
                    Symbol(elem.name) => Geometry(
                        ref_meshes[geom[:shapeIndex]],
                        transformation,
                        geom[:dUp],
                        geom[:dDwn],
                    )
                )
            end
        elseif elem.name in ["decomp", "branch", "follow"]
            parse_opf_topology!(elem, node_i, features, attr_type, mtg_type, ref_meshes, read_id, max_id)
        else
            error("Attribute $(elem.name) not found in attributeBDD (or badly written?)")
        end
    end

    for (k, v) in attrs
        node_i[k] = v
    end

    return node_i
end
