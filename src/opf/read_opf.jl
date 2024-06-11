"""
    read_opf(file; attr_type = Dict, mtg_type = MutableNodeMTG)

Read an OPF file, and returns an MTG.

# Arguments

- `file::String`: The path to the opf file.
- `attr_type::DataType = Dict`: the type used to hold the attribute values for each node.
- `mtg_type = MutableNodeMTG`: the type used to hold the mtg encoding for each node (*i.e.*
link, symbol, index, scale). See details section below.
- `read_id::Bool = true`: whether to read the ID from the OPF or recompute it on the fly.
- `max_id::RefValue{Int64}=Ref(1)`: the ID of the first node, if `read_id==false`.

# Details

`attr_type` should be:

- `NamedTuple` if you don't plan to modify the attributes of the mtg, *e.g.* to use them for
plotting or computing statistics...
- `MutableNamedTuple` if you plan to modify the attributes values but not adding new attributes
very often, *e.g.* recompute an attribute value...
- `Dict` or similar (*e.g.* `OrderedDict`) if you plan to heavily modify the attributes, *e.g.*
adding/removing attributes a lot

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
            push!(opf_attr, :meshBDD => parse_meshBDD!(node))
        end

        if node.name == "materialBDD"
            push!(
                opf_attr,
                :materialBDD => parse_materialBDD!(node)
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

            append!(
                mtg,
                MultiScaleTreeGraph.parse_node_attributes(
                    attr_type,
                    Dict(:ref_meshes => ref_meshes)
                )
            )
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
        parsed = map(x -> x == "NA" ? nothing : parse(type, x), split(elem))
        if length(parsed) == 1
            return parsed[1]
        else
            return parsed
        end
    end
end



# struct TestMesh{N<:AbstractVector,T<:AbstractVector}
#     points::N
#     faces::T
# end

struct OPFmesh{M<:Meshes.SimpleMesh,N<:AbstractVector,T<:Union{AbstractVector,Nothing}}
    name::String
    enableScale::Bool
    mesh::M
    normals::N
    textureCoords::T # texture coordinates (length = length(points) * 2/3, or Nothing)
end

"""
Parse the meshBDD using [`parse_opf_array`](@ref)
"""
function parse_meshBDD!(node)
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
                content = parse_opf_array(i.content, Int) .+ 1
                # NB: adding 1 to the faces because the opf is 0-based but Julia is 1-based

                faces3d = Meshes.Connectivity[
                    Meshes.connect((content[p], content[p+1], content[p+2]), Meshes.Triangle) for p = 1:3:length(content)
                ]

                push!(mesh, "faces" => faces3d)
            elseif i.name == "textureCoords"
                content = parse_opf_array(i.content)
                content = Meshes.Point2[
                    Meshes.Point2(content[[i, i + 1]]) for i in 1:2:length(content)
                ]
                push!(mesh, "textureCoords" => content)
            else
                content = parse_opf_array(i.content)
                content = Meshes.Point3[
                    Meshes.Point3(content[[i, i + 1, i + 2]]) for i in 1:3:length(content)
                ]
                push!(mesh, i.name => content)
            end
        end

        push!(
            meshes,
            parse(Int, m["Id"]) + 1 =>
                OPFmesh(
                    mesh["name"],
                    mesh["enableScale"],
                    Meshes.SimpleMesh(mesh["points"], mesh["faces"]),
                    get(mesh, "normals", nothing),
                    get(mesh, "textureCoords", nothing), # using get because sometimes missing
                )
        )
    end

    return meshes
end

"""
Parse the materialBDD using [`parse_opf_elements!`](@ref)
"""
function parse_materialBDD!(node)
    metBDDraw = parse_opf_elements!(
        node,
        [Float64, Float64, Float64, Float64, Float64]
    )
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
    link = "/" # default, for "topology" and "decomp"
    b = Vec(0.0, 0.0, 0.0)
    if node.name == "branch"
        link = "+"
    elseif node.name == "follow"
        link = "<"
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
            MultiScaleTreeGraph.init_empty_attr(attr_type)
        )
    else
        # First node:
        node_i = Node(id, MTG, MultiScaleTreeGraph.init_empty_attr(attr_type))
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
                #! to the Point3 when transforming it with the 4x4 matrix?

                transformation = Affine(@view(geom[:mat][1:3, 1:3]), b) → Translate(@view(geom[:mat][1:3, 4])...)
                # transformation = Translation(geom[:mat][1:3, 4]) ∘ LinearMap(geom[:mat][1:3, 1:3]) # CoordinateTransformations
                # NB: We read an homogeneous transformation matrix from the OPF, but we work
                # with cartesian coordinates in PlantGeom by design. So we deconstruct our
                # homogeneous matrix into the two corresponding rotation and translation
                # matrices, and create a transformation from them using transformation
                # composition from Meshes.jl. Note that our homogeneous
                # matrix is rotate first, then translate (hence the order of transformation)

                push!(
                    attrs,
                    Symbol(elem.name) => geometry(
                        ref_meshes.meshes[geom[:shapeIndex]],
                        geom[:shapeIndex],
                        transformation,
                        geom[:dUp],
                        geom[:dDwn],
                        nothing,
                    )
                )
            end
        elseif elem.name in ["decomp", "branch", "follow"]
            parse_opf_topology!(elem, node_i, features, attr_type, mtg_type, ref_meshes, read_id, max_id)
        else
            error("Attribute $(elem.name) not found in attributeBDD (or badly written?)")
        end
    end

    append!(node_i, MultiScaleTreeGraph.parse_node_attributes(attr_type, attrs))

    return node_i
end
