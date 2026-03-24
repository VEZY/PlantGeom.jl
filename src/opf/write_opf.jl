using Printf: @sprintf

"""
    write_opf(file, opf)

Write an MTG with explicit geometry to disk as an OPF file.
"""
@inline _opf_scalar_string(x::AbstractFloat) = @sprintf("%.17g", Float64(x))
@inline _opf_scalar_string(x) = string(x)
@inline _opf_join_values(values) = join((_opf_scalar_string(v) for v in values), "\t")
@inline _opf_attr_string(val::AbstractArray) = _opf_join_values(val)
@inline _opf_attr_string(val) = _opf_scalar_string(val)
@inline _opf_skip_attribute(key::Symbol) = key in (:ref_meshes, :geometry, :source_topology_id, :description) || startswith(String(key), "_scene_")

@inline _opf_geometry_material(geom::Geometry) = geom.ref_mesh.material
@inline _opf_geometry_material(geom::PointMappedGeometry) = geom.ref_mesh.material
@inline _opf_geometry_material(geom::ExtrudedTubeGeometry) = geom.material
@inline _opf_geometry_material(geom) = geometry_display_color(geom)

@inline _opf_geometry_texture_coords(::Any) = nothing
@inline _opf_geometry_texture_coords(geom::PointMappedGeometry) = geom.ref_mesh.texture_coords

function _materialized_geometry_ref_mesh(node, geom)
    mesh_ = geometry_to_mesh(geom)
    RefMesh(
        string(get_ref_mesh_name(geom), "_node_", node_id(node)),
        mesh_,
        normals_vertex(mesh_),
        _opf_geometry_texture_coords(geom),
        _opf_geometry_material(geom),
        false,
    )
end

function _opf_serialization_context(mtg)
    root = get_root(mtg)
    ref_meshes = Dict{Int,RefMesh}()
    ref_mesh_lookup = IdDict{Any,Int}()
    materialized_lookup = IdDict{Any,Int}()
    serialized_geometries = IdDict{Any,NamedTuple{(:shape_index, :transformation, :dUp, :dDwn),Tuple{Int,Transformation,Float64,Float64}}}()
    next_id = 0

    traverse!(root) do node
        has_geometry(node) || return

        geom = node[:geometry]
        if geom isa Geometry
            mesh_id = get(ref_mesh_lookup, geom.ref_mesh, nothing)
            if isnothing(mesh_id)
                mesh_id = next_id
                ref_meshes[mesh_id] = geom.ref_mesh
                ref_mesh_lookup[geom.ref_mesh] = mesh_id
                next_id += 1
            end

            serialized_geometries[node] = (
                shape_index=mesh_id,
                transformation=geom.transformation,
                dUp=Float64(geom.dUp),
                dDwn=Float64(geom.dDwn),
            )
            return
        end

        mesh_id = get(materialized_lookup, geom, nothing)
        if isnothing(mesh_id)
            mesh_id = next_id
            ref_meshes[mesh_id] = _materialized_geometry_ref_mesh(node, geom)
            materialized_lookup[geom] = mesh_id
            next_id += 1
        end

        serialized_geometries[node] = (
            shape_index=mesh_id,
            transformation=IdentityTransformation(),
            dUp=1.0,
            dDwn=1.0,
        )
    end

    return ref_meshes, serialized_geometries
end

function write_opf(file, mtg)
    clean_cache!(mtg)

    doc = XMLDocument()
    opf_elm = ElementNode("opf")
    setroot!(doc, opf_elm)
    opf_elm["version"] = 2.0
    opf_elm["editable"] = true

    meshBDD = addelement!(opf_elm, "meshBDD")

    ref_meshes, serialized_geometries = _opf_serialization_context(mtg)

    for (id, mesh_) in ref_meshes
        mesh_elm = addelement!(meshBDD, "mesh")
        mesh_elm["name"] = mesh_.name
        mesh_elm["shape"] = ""
        mesh_elm["Id"] = id
        mesh_elm["enableScale"] = mesh_.taper

        points_cm = Iterators.flatten((p[1] * 100, p[2] * 100, p[3] * 100) for p in _vertices(mesh_.mesh))
        addelement!(mesh_elm, "points", string("\n", _opf_join_values(points_cm), "\n"))

        if length(mesh_.normals) == nelements(mesh_) && length(mesh_.normals) != nvertices(mesh_)
            vertex_normals = normals_vertex(mesh_)
        else
            vertex_normals = mesh_.normals
        end

        normals_flat = Iterators.flatten((n[1], n[2], n[3]) for n in vertex_normals)
        addelement!(mesh_elm, "normals", string("\n", _opf_join_values(normals_flat), "\n"))

        if mesh_.texture_coords !== nothing && length(mesh_.texture_coords) > 0
            uv_flat = Iterators.flatten((uv[1] * 100, uv[2] * 100) for uv in mesh_.texture_coords)
            addelement!(mesh_elm, "textureCoords", string("\n", _opf_join_values(uv_flat), "\n"))
        end

        faces_elm = addelement!(mesh_elm, "faces")
        face_id = 0
        for tri in _faces(mesh_.mesh)
            face_elm = addelement!(faces_elm, "face", string("\n", _opf_join_values((tri[1] - 1, tri[2] - 1, tri[3] - 1)), "\n"))
            face_elm["Id"] = face_id
            face_id += 1
        end
    end

    materialBDD = addelement!(opf_elm, "materialBDD")
    for (id, mesh_) in ref_meshes
        mat_elm = addelement!(materialBDD, "material")
        mat_elm["Id"] = id

        mat = material_to_opf_string(mesh_.material)
        addelement!(mat_elm, "emission", mat[:emission])
        addelement!(mat_elm, "ambient", mat[:ambient])
        addelement!(mat_elm, "diffuse", mat[:diffuse])
        addelement!(mat_elm, "specular", mat[:specular])
        addelement!(mat_elm, "shininess", mat[:shininess])
    end

    shapeBDD = addelement!(opf_elm, "shapeBDD")
    for (id, mesh_) in ref_meshes
        shape_elm = addelement!(shapeBDD, "shape")
        shape_elm["Id"] = id

        addelement!(shape_elm, "name", mesh_.name)
        addelement!(shape_elm, "meshIndex", string(id))
        addelement!(shape_elm, "materialIndex", string(id))
    end

    attrBDD = addelement!(opf_elm, "attributeBDD")
    attrs = MultiScaleTreeGraph.get_features(mtg)
    for i in eachindex(attrs.NAME)
        attr_name = attrs.NAME[i]
        attr_type = attrs.TYPE[i]
        _opf_skip_attribute(attr_name) && continue

        shape_elm = addelement!(attrBDD, "attribute")
        shape_elm["name"] = string(attr_name)

        if attr_type == "STRING"
            attr_type_opf = "String"
        elseif attr_type == "REAL"
            attr_type_opf = "Double"
        elseif attr_type == "INT"
            attr_type_opf = "Integer"
        elseif attr_type == "BOOLEAN"
            attr_type_opf = "Boolean"
        else
            error("Unknown attribute type: $(attr_type) for attribute $(attr_name)")
        end

        shape_elm["class"] = attr_type_opf
    end

    mtg_topology_to_xml!(mtg, opf_elm, nothing, serialized_geometries)

    write(file, doc)

    return nothing
end

"""
    mtg_to_opf_link(link)
"""
function mtg_to_opf_link(link)
    link_sym = link isa Symbol ? link : Symbol(link)
    if link_sym == :/
        "decomp"
    elseif link_sym == :<
        "follow"
    elseif link_sym == :+
        "branch"
    else
        error("Unknown MTG link: $link")
    end
end

"""
    mtg_topology_to_xml!(node, xml_parent)

Write the MTG topology, attributes and geometry into XML format.
"""
function mtg_topology_to_xml!(node, xml_parent, xml_gtparent=nothing, serialized_geometries=IdDict{Any,NamedTuple{(:shape_index, :transformation, :dUp, :dDwn),Tuple{Int,Transformation,Float64,Float64}}}())
    if isroot(node)
        xml_parent = attributes_to_xml(node, xml_parent, xml_gtparent, serialized_geometries)
    end

    if !isleaf(node)
        for chnode in children(node)
            xml_node = attributes_to_xml(chnode, xml_parent, xml_gtparent, serialized_geometries)
            mtg_topology_to_xml!(chnode, xml_node, xml_parent, serialized_geometries)
        end
    end
end

"""
    attributes_to_xml(node, xml_parent)

Write an MTG node into an XML node.
"""
function attributes_to_xml(node, xml_parent, xml_gtparent, serialized_geometries)
    opf_link = isroot(node) ? "topology" : mtg_to_opf_link(link(node))

    xml_node = addelement!(xml_parent, opf_link)

    xml_node["class"] = string(symbol(node))
    xml_node["scale"] = scale(node)
    xml_node["id"] = hasproperty(node, :source_topology_id) ? node.source_topology_id : node_id(node)

    for key in keys(node)
        if key == :geometry
            geom_val = node[key]
            (geom_val === nothing || ismissing(geom_val)) && continue
            serialized_geom = get(serialized_geometries, node, nothing)
            isnothing(serialized_geom) && error("Geometry serialization context not found for node $(node_id(node)).")

            geom = addelement!(xml_node, string(key))
            geom["class"] = "Mesh"

            addelement!(geom, "shapeIndex", string(serialized_geom.shape_index))

            mat4x4 = get_transformation_matrix(serialized_geom.transformation)

            addelement!(
                geom,
                "mat",
                string(
                    "\n",
                    _opf_join_values(mat4x4[1, :]),
                    "\n",
                    _opf_join_values(mat4x4[2, :]),
                    "\n",
                    _opf_join_values(mat4x4[3, :]),
                    "\n"
                )
            )
            addelement!(geom, "dUp", _opf_scalar_string(serialized_geom.dUp))
            addelement!(geom, "dDwn", _opf_scalar_string(serialized_geom.dDwn))
        elseif _opf_skip_attribute(key)
            continue
        else
            val = node[key]
            val === nothing && continue
            addelement!(xml_node, string(key), _opf_attr_string(val))
        end
    end

    return xml_node
end

function get_transformation_matrix(trans::Transformation)
    mat = transformation_matrix4(trans)
    mat_cm = copy(mat)
    mat_cm[1:3, 4] .*= 100
    mat_cm
end

function get_transformation_matrix(::T) where {T<:UniformScaling}
    Matrix{Float64}(I, 4, 4)
end
