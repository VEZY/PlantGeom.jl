"""
    write_opf(file, opf)

Write an MTG with explicit geometry to disk as an OPF file.
"""
function write_opf(file, mtg)
    clean_cache!(mtg)

    doc = XMLDocument()
    opf_elm = ElementNode("opf")
    setroot!(doc, opf_elm)
    opf_elm["version"] = 2.0
    opf_elm["editable"] = true

    meshBDD = addelement!(opf_elm, "meshBDD")

    if mtg[:ref_meshes] === nothing
        mtg[:ref_meshes] = get_ref_meshes(mtg)
    end

    for (id, mesh_) in mtg[:ref_meshes]
        mesh_elm = addelement!(meshBDD, "mesh")
        mesh_elm["name"] = mesh_.name
        mesh_elm["shape"] = ""
        mesh_elm["Id"] = id
        mesh_elm["enableScale"] = mesh_.taper

        points_cm = Iterators.flatten((p[1] * 100, p[2] * 100, p[3] * 100) for p in _vertices(mesh_.mesh))
        addelement!(mesh_elm, "points", string("\n", join(points_cm, "\t"), "\n"))

        if length(mesh_.normals) == nelements(mesh_) && length(mesh_.normals) != nvertices(mesh_)
            vertex_normals = normals_vertex(mesh_)
        else
            vertex_normals = mesh_.normals
        end

        normals_flat = Iterators.flatten((n[1], n[2], n[3]) for n in vertex_normals)
        addelement!(mesh_elm, "normals", string("\n", join(normals_flat, "\t"), "\n"))

        if mesh_.texture_coords !== nothing && length(mesh_.texture_coords) > 0
            uv_flat = Iterators.flatten((uv[1] * 100, uv[2] * 100) for uv in mesh_.texture_coords)
            addelement!(mesh_elm, "textureCoords", string("\n", join(uv_flat, "\t"), "\n"))
        end

        faces_elm = addelement!(mesh_elm, "faces")
        face_id = 0
        for tri in _faces(mesh_.mesh)
            face_elm = addelement!(faces_elm, "face", string("\n", join((tri[1] - 1, tri[2] - 1, tri[3] - 1), "\t"), "\n"))
            face_elm["Id"] = face_id
            face_id += 1
        end
    end

    materialBDD = addelement!(opf_elm, "materialBDD")
    for (id, mesh_) in mtg[:ref_meshes]
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
    for (id, mesh_) in mtg[:ref_meshes]
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
        (attr_name == :ref_meshes || attr_name == :geometry) && continue

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

    mtg_topology_to_xml!(mtg, opf_elm)

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
function mtg_topology_to_xml!(node, xml_parent, xml_gtparent=nothing, ref_meshes=get_ref_meshes(node))
    if isroot(node)
        xml_parent = attributes_to_xml(node, xml_parent, xml_gtparent, ref_meshes)
    end

    if !isleaf(node)
        for chnode in children(node)
            xml_node = attributes_to_xml(chnode, xml_parent, xml_gtparent, ref_meshes)
            mtg_topology_to_xml!(chnode, xml_node, xml_parent, ref_meshes)
        end
    end
end

"""
    attributes_to_xml(node, xml_parent)

Write an MTG node into an XML node.
"""
function attributes_to_xml(node, xml_parent, xml_gtparent, ref_meshes)
    opf_link = isroot(node) ? "topology" : mtg_to_opf_link(link(node))

    xml_node = addelement!(xml_parent, opf_link)

    xml_node["class"] = string(symbol(node))
    xml_node["scale"] = scale(node)
    xml_node["id"] = node_id(node)

    for key in keys(node)
        if key == :geometry
            geom = addelement!(xml_node, string(key))
            geom["class"] = "Mesh"

            ref_mesh_index = findfirst(x -> x === node[key].ref_mesh, ref_meshes)
            addelement!(geom, "shapeIndex", string(ref_mesh_index - 1))

            mat4x4 = get_transformation_matrix(node[key].transformation)

            addelement!(
                geom,
                "mat",
                string(
                    "\n",
                    join(mat4x4[1, :], "\t"),
                    "\n",
                    join(mat4x4[2, :], "\t"),
                    "\n",
                    join(mat4x4[3, :], "\t"),
                    "\n"
                )
            )
            addelement!(geom, "dUp", string(node[key].dUp))
            addelement!(geom, "dDwn", string(node[key].dDwn))
        elseif key == :ref_meshes
            continue
        else
            val = node[key]
            val === nothing && continue
            addelement!(xml_node, string(key), string(val))
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
