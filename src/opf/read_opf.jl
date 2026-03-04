"""
    read_opf(file; attr_type = Dict, mtg_type = MutableNodeMTG, attribute_types = Dict())

Read an OPF file, and returns an MTG.

# Arguments

- `file::String`: The path to the opf file.
- `attr_type::DataType = Dict`: kept for backward compatibility and ignored for
  MultiScaleTreeGraph >= v0.15 (typed columnar attributes backend is always used).
- `mtg_type = MutableNodeMTG`: the type used to hold the mtg encoding for each node (*i.e.*
link, symbol, index, scale). See details section below.
- `read_id::Bool = true`: whether to read the ID from the OPF or recompute it on the fly.
- `max_id::RefValue{Int64}=Ref(1)`: the ID of the first node, if `read_id==false`.
- `attribute_types::Dict = Dict()`: optional explicit mapping from attribute name (`String` or `Symbol`)
  to Julia type (`Int*`, `Float*`, `Bool`, `String`). When provided, it overrides `attributeBDD`.

Each parsed topology node stores its original OPF id in `:source_topology_id`.

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

The MTG root node. OPF reference meshes are attached on the root as
`opf[:ref_meshes]::Dict{Int,RefMesh}`, keyed by OPF shape IDs (`shapeIndex`,
typically 0-based).

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
    max_id=Ref(1),
    attribute_types=Dict()
)

    doc = readxml(file)
    xroot = root(doc)

    if xroot.name != "opf"
        error("The file is not an OPF")
    end

    if xroot["version"] != "2.0"
        error("Cannot read OPF files version other than 2.0")
    end

    editable = haskey(xroot, "editable") ? parse(Bool, xroot["editable"]) : true

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
            shapeBDD = parse_shapeBDD!(node)
            push!(opf_attr, :shapeBDD => shapeBDD)
        end

        if node.name == "attributeBDD"
            push!(opf_attr, :attributeBDD => parse_opf_attributeBDD!(node))
        end

        if node.name == "topology"
            ref_meshes = parse_ref_meshes(opf_attr)
            
            # Handle missing attributeBDD by creating an empty one that will be populated dynamically
            if !haskey(opf_attr, :attributeBDD)
                opf_attr[:attributeBDD] = Dict{String,String}()
            end

            features = get_attr_type(opf_attr[:attributeBDD])
            normalized_attribute_types = _normalize_attribute_types(attribute_types)
            for (attr_name, type_) in normalized_attribute_types
                features[attr_name] = type_
                opf_attr[:attributeBDD][attr_name] = _julia_attr_type_to_opf_class(type_)
            end
            
            mtg = parse_opf_topology!(
                node,
                nothing,
                features,
                attr_type,
                mtg_type,
                ref_meshes,
                read_id,
                max_id,
                opf_attr[:attributeBDD],   # Pass attributeBDD for dynamic updates
                normalized_attribute_types # Explicit user mapping (CSV-like override)
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

function _parse_opf_numeric_vector(raw_content::AbstractString, ::Type{T}) where {T<:Number}
    tokens = split(strip(raw_content))
    values = Vector{T}(undef, length(tokens))
    @inbounds for i in eachindex(tokens)
        parsed = tryparse(T, tokens[i])
        isnothing(parsed) && error("Could not parse OPF numeric token '$(tokens[i])' as $T.")
        values[i] = parsed
    end
    return values
end

@inline function _opf_points3_from_flat(values::AbstractVector{<:Real}, scale_factor::Real=1.0)
    length(values) % 3 == 0 || error("Invalid OPF point array length $(length(values)); expected a multiple of 3.")
    out = Vector{GeometryBasics.Point{3,Float64}}(undef, length(values) ÷ 3)
    j = 1
    @inbounds for i in 1:3:length(values)
        out[j] = point3(values[i] * scale_factor, values[i + 1] * scale_factor, values[i + 2] * scale_factor)
        j += 1
    end
    return out
end

@inline function _opf_vec3_from_flat(values::AbstractVector{<:Real})
    length(values) % 3 == 0 || error("Invalid OPF vec3 array length $(length(values)); expected a multiple of 3.")
    out = Vector{GeometryBasics.Vec{3,Float64}}(undef, length(values) ÷ 3)
    j = 1
    @inbounds for i in 1:3:length(values)
        out[j] = vec3(values[i], values[i + 1], values[i + 2])
        j += 1
    end
    return out
end

@inline function _opf_points2_from_flat(values::AbstractVector{<:Real}, scale_factor::Real=1.0)
    length(values) % 2 == 0 || error("Invalid OPF uv array length $(length(values)); expected a multiple of 2.")
    out = Vector{GeometryBasics.Point{2,Float64}}(undef, length(values) ÷ 2)
    j = 1
    @inbounds for i in 1:2:length(values)
        out[j] = GeometryBasics.Point{2,Float64}(values[i] * scale_factor, values[i + 1] * scale_factor)
        j += 1
    end
    return out
end

function parse_shapeBDD!(node)
    shapeBDD = Dict{Int,Dict{String,Any}}()
    for shape_node in eachelement(node)
        shape_node.name == "shape" || continue
        shape_id = parse(Int, shape_node["Id"])
        name = ""
        mesh_index = 0
        material_index = 0
        for child in eachelement(shape_node)
            if child.name == "name"
                name = strip(child.content)
            elseif child.name == "meshIndex"
                mesh_index = parse(Int, child.content)
            elseif child.name == "materialIndex"
                material_index = parse(Int, child.content)
            end
        end
        shapeBDD[shape_id] = Dict(
            "name" => name,
            "meshIndex" => mesh_index,
            "materialIndex" => material_index,
        )
    end
    return shapeBDD
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
        flat_ids = _parse_opf_numeric_vector(elem.content, Int)
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
        mesh_name = m["name"]
        enable_scale = haskey(m, "enableScale") ? parse(Bool, m["enableScale"]) : true
        mesh_points = GeometryBasics.Point{3,Float64}[]
        mesh_faces = Face3[]
        mesh_normals = nothing
        mesh_texture_coords = nothing

        for i in eachelement(m)
            if i.name == "faces"
                mesh_faces = _opf_parse_faces(i, file, mesh_name)
            elseif i.name == "textureCoords"
                content = _parse_opf_numeric_vector(i.content, Float64)
                mesh_texture_coords = _opf_points2_from_flat(content, 0.01)
            elseif i.name == "normals"
                content = _parse_opf_numeric_vector(i.content, Float64)
                mesh_normals = _opf_vec3_from_flat(content)
            elseif i.name == "points"
                content = _parse_opf_numeric_vector(i.content, Float64)
                mesh_points = _opf_points3_from_flat(content, 0.01)
            else
                error("Unknown node element for mesh$(i.Id) in mesh BDD: $(i.name)")
            end
        end

        push!(
            meshes,
            parse(Int, m["Id"]) =>
                OPFmesh(
                    mesh_name,
                    enable_scale,
                    _mesh(mesh_points, mesh_faces),
                    mesh_normals,
                    mesh_texture_coords,
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
    if isempty(collect(eachelement(node)))
        return Dict(1 => _default_phong_material())
    end

    metBDD = Dict{Int,Phong}()
    for material_node in eachelement(node)
        material_node.name == "material" || continue
        material_id = parse(Int, material_node["Id"])
        raw = Dict{String,Any}()
        for child in eachelement(material_node)
            if child.name == "shininess"
                raw["shininess"] = parse(Float64, child.content)
            else
                raw[child.name] = _parse_opf_numeric_vector(child.content, Float64)
            end
        end
        metBDD[material_id] = materialBDD_to_material(raw)
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
        push!(elem_dict, parse(Int, m["Id"]) => elems_)
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
    attr_type = Dict{String,DataType}()
    for (name, class_name) in attr
        attr_type[String(name)] = _opf_attr_class_to_julia_type(String(class_name))
    end
    attr_type
end

@inline function _opf_attr_class_to_julia_type(class_name::String)
    if class_name in ["Object", "String", "Color", "Image"]
        return String
    elseif class_name == "Integer"
        return Int32
    elseif class_name in ["Double", "Metre", "Centimetre", "Millimetre", "10E-5 Metre", "Metre_100"]
        return Float32
    elseif class_name == "Boolean"
        return Bool
    else
        error("Attribute type `$(class_name)` not recognised in attributeBDD.")
    end
end

@inline function _julia_attr_type_to_opf_class(type_::DataType)
    if type_ <: Integer
        return "Integer"
    elseif type_ <: AbstractFloat
        return "Double"
    elseif type_ == Bool
        return "Boolean"
    elseif type_ <: AbstractString
        return "String"
    else
        return "String"
    end
end

function _normalize_attribute_types(attribute_types)
    normalized = Dict{String,DataType}()
    isnothing(attribute_types) && return normalized

    for (name, type_) in attribute_types
        attr_name = String(name)
        attr_type = type_ isa DataType ? type_ : (type_ isa Type ? type_ : nothing)
        isnothing(attr_type) && error(
            "Invalid attribute type override for '$attr_name': expected a Julia type, got $(typeof(type_))."
        )

        normalized[attr_name] = if attr_type == Bool
            Bool
        elseif attr_type <: Integer
            Int64
        elseif attr_type <: AbstractFloat
            Float64
        elseif attr_type <: AbstractString
            String
        else
            error(
                "Unsupported attribute type override for '$attr_name': $attr_type. " *
                "Use integer, float, bool, or string types."
            )
        end
    end

    normalized
end

@inline function _infer_dynamic_attribute_type(raw_content::AbstractString)
    tokens = split(strip(raw_content))
    isempty(tokens) && return String

    non_na_tokens = filter(t -> t != "NA" && !isempty(t), tokens)
    isempty(non_na_tokens) && return String

    if all(t -> !isnothing(tryparse(Int64, t)), non_na_tokens)
        return Int32
    end

    if all(t -> !isnothing(tryparse(Float64, t)), non_na_tokens)
        return Float32
    end

    if all(t -> lowercase(t) in ("true", "false"), non_na_tokens)
        return Bool
    end

    String
end

@inline function _next_dynamic_attribute_type(type_::DataType)
    if type_ <: Integer
        return Float32
    elseif type_ <: AbstractFloat
        return String
    elseif type_ == Bool
        return String
    else
        return nothing
    end
end

function _try_parse_opf_array(raw_content::AbstractString, type_::DataType)
    if type_ <: AbstractString
        return strip(raw_content), true
    end

    tokens = split(raw_content)
    parsed = Vector{Any}(undef, length(tokens))

    for (i, token) in enumerate(tokens)
        if token == "NA" || isempty(token)
            parsed[i] = nothing
            continue
        end

        parsed_value = if type_ == Bool
            lower = lowercase(token)
            lower == "true" ? true : (lower == "false" ? false : nothing)
        else
            tryparse(type_, token)
        end

        if isnothing(parsed_value)
            return nothing, false
        end
        parsed[i] = parsed_value
    end

    if length(parsed) == 1
        return parsed[1], true
    end
    parsed, true
end

function _parse_dynamic_attribute_value!(
    raw_content::AbstractString,
    attr_name::String,
    features::Dict{String,DataType},
    attributeBDD::Dict{String,String}
)
    current_type = features[attr_name]
    parsed_value, ok = _try_parse_opf_array(raw_content, current_type)
    ok && return parsed_value

    while true
        next_type = _next_dynamic_attribute_type(current_type)
        isnothing(next_type) && break
        current_type = next_type
        parsed_value, ok = _try_parse_opf_array(raw_content, current_type)
        if ok
            features[attr_name] = current_type
            attributeBDD[attr_name] = _julia_attr_type_to_opf_class(current_type)
            return parsed_value
        end
    end

    # Last-resort fallback for mixed non-numeric values.
    features[attr_name] = String
    attributeBDD[attr_name] = "String"
    strip(raw_content)
end


"""
Parse the geometry element of the OPF.

# Note
The transformation matrix is 3*4.
elem = elem.content
"""
function parse_geometry(elem)
    shape_index = nothing
    mat = nothing
    d_up = 1.0
    d_dwn = 1.0

    for i in eachelement(elem)
        if i.name == "shapeIndex"
            shape_index = parse(Int, i.content)
        elseif i.name == "mat"
            mat = SMatrix{3,4}(reshape(_parse_opf_numeric_vector(i.content, Float64), 4, 3)')
        elseif i.name == "dUp"
            d_up = parse(Float64, i.content)
        elseif i.name == "dDwn"
            d_dwn = parse(Float64, i.content)
        end
    end

    return (; shapeIndex=shape_index, mat=mat, dUp=d_up, dDwn=d_dwn)
end


"""

    parse_opf_topology!(node, mtg, features, attr_type, mtg_type, ref_meshes, ...)

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
- `attributeBDD::Dict{String,String}=Dict{String,String}()`: the attributeBDD for dynamic attribute type discovery.
- `attribute_types::Dict{String,DataType}=Dict{String,DataType}()`: explicit user type mapping.
- `dynamic_attributes::Set{String}=Set{String}()`: names of attributes inferred dynamically.

# Note

The transformation matrices in `geometry` are 3*4.
"""
function parse_opf_topology!(
    node,
    mtg,
    features,
    attr_type,
    mtg_type,
    ref_meshes,
    read_id=true,
    max_id=Ref(1),
    attributeBDD=Dict{String,String}(),
    attribute_types=Dict{String,DataType}(),
    dynamic_attributes=Set{String}()
)
    link = :/ # default, for "topology" and "decomp"
    if node.name == "branch"
        link = :+
    elseif node.name == "follow"
        link = :<
    end

    source_topology_id = parse(Int, node["id"])
    if read_id
        id = source_topology_id
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

    node_i.source_topology_id = source_topology_id

    # Handle the children, can be attributes of children nodes:
    # elem = elements(node)[1]
    for elem in eachelement(node)
        if elem.name == "geometry"
            geom = parse_geometry(elem)

            # Parse the geometry (transformation, reference mesh + index and dUp and dDwn):
            if !isnothing(geom.shapeIndex)
                # Rotation + Scaling. No need to decouple them here, but in case we need to
                # in the future, see: https://stackoverflow.com/a/29618569/6947799
                # See also this for decomposition: https://colab.research.google.com/drive/1ImBB-N6P9zlNMCBH9evHD6tjk0dzvy1_

                #! OK what I could do is use my own transformation function that adds w (=1)
                #! to the Point when transforming it with the 4x4 matrix?

                isnothing(geom.mat) && error("Missing transformation matrix in OPF geometry for node id $(source_topology_id).")
                A = SMatrix{3,3,Float64}(@view(geom.mat[1:3, 1:3]))
                t = SVector{3,Float64}((@view(geom.mat[1:3, 4])) ./ 100)
                transformation = AffineMap(A, t)
                # NB: We read an homogeneous transformation matrix from the OPF, but we work
                # with cartesian coordinates in PlantGeom by design. So we deconstruct our
                # homogeneous matrix into the two corresponding rotation and translation
                # matrices and create a single affine transform.

                node_i.geometry = Geometry(
                    ref_meshes[geom.shapeIndex],
                    transformation,
                    geom.dUp,
                    geom.dDwn,
                )
            end
        elseif elem.name in ["decomp", "branch", "follow"]
            parse_opf_topology!(
                elem,
                node_i,
                features,
                attr_type,
                mtg_type,
                ref_meshes,
                read_id,
                max_id,
                attributeBDD,
                attribute_types,
                dynamic_attributes
            )
        else
            attr_name = elem.name

            if !haskey(features, attr_name)
                if haskey(attribute_types, attr_name)
                    features[attr_name] = attribute_types[attr_name]
                    attributeBDD[attr_name] = _julia_attr_type_to_opf_class(attribute_types[attr_name])
                elseif haskey(attributeBDD, attr_name)
                    features[attr_name] = _opf_attr_class_to_julia_type(attributeBDD[attr_name])
                else
                    inferred_type = _infer_dynamic_attribute_type(elem.content)
                    features[attr_name] = inferred_type
                    attributeBDD[attr_name] = _julia_attr_type_to_opf_class(inferred_type)
                    push!(dynamic_attributes, attr_name)
                end
            end

            if haskey(features, attr_name)
                parsed_attr = if (attr_name in dynamic_attributes) && !haskey(attribute_types, attr_name)
                    _parse_dynamic_attribute_value!(elem.content, attr_name, features, attributeBDD)
                else
                    parse_opf_array(elem.content, features[attr_name])
                end
                node_i[Symbol(attr_name)] = parsed_attr
            else
                error("Attribute $(attr_name) not found in attributeBDD (or badly written?)")
            end
        end
    end

    return node_i
end
