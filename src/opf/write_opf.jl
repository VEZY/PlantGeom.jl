"""
    write_opf(opf, file)

Write an MTG with explicit geometry to disk as an OPF file.

# Notes

Node attributes `:mesh`, `:ref_meshes` and `:geometry` are treated as reserved keywords and
should not be used without knowing their meaning:

- `:ref_meshes`: a `RefMeshes` structure that holds the MTG reference meshes.
- `:geometry`: a Dict of four:
    - `:shapeIndex`: the index of the node reference mesh
    - `:dUp`: tappering in the upper direction
    - `:dDwn`: tappering in the bottom direction
    - `:mat`: the transformation matrix (4x4)
- `:mesh`: a `SimpleMesh` computed from a reference mesh (`:ref_meshes`) and a transformation
matrix (`:geometry`).

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")
opf = read_opf(file)

write_opf("test.opf", opf)
```
"""
function write_opf(file, mtg)
    doc = XMLDocument()
    opf_elm = ElementNode("opf")
    setroot!(doc, opf_elm)
    opf_elm["version"] = 2.0
    opf_elm["editable"] = true

    # Writing the reference meshes (meshBDD):
    meshBDD = addelement!(opf_elm, "meshBDD")

    if mtg[:ref_meshes] === nothing
        error("No reference meshes found in the MTG.")
    end

    for (key, mesh) in enumerate(mtg[:ref_meshes].meshes)
        mesh_elm = addelement!(meshBDD, "mesh")
        mesh_elm["name"] = mesh.name
        mesh_elm["shape"] = ""
        mesh_elm["Id"] = key
        mesh_elm["enableScale"] = mesh.taper

        addelement!(
            mesh_elm,
            "points",
            string("\n", join([vcat([p.coords for p in mesh.mesh.points]...)...], "\t"), "\n")
        )

        norm_elm = addelement!(
            mesh_elm,
            "normals",
            string("\n", join(mesh.normals, "\t"), "\n")
        )

        if length(mesh.textureCoords) > 0
            # textureCoords are optional
            norm_elm = addelement!(
                mesh_elm,
                "textureCoords",
                string("\n", join(mesh.textureCoords, "\t"), "\n")
            )
        end

        faces_elm = addelement!(mesh_elm, "faces")

        face_id = [0]
        for i = 1:nelements(mesh.mesh.topology)
            face_elm = addelement!(
                faces_elm,
                "face",
                string("\n", join(mesh.mesh.topology.connec[i].indices .- 1, "\t"), "\n")
            )
            #? NB: we remove one because face index are 0-based in the opf
            face_elm["Id"] = face_id[1]
            face_id[1] = face_id[1] + 1
        end

    end

    # Parsing the materialBDD section.
    materialBDD = addelement!(opf_elm, "materialBDD")
    for (key, mesh) in enumerate(mtg[:ref_meshes].meshes)
        mat_elm = addelement!(materialBDD, "material")
        mat_elm["Id"] = key

        addelement!(
            mat_elm,
            "emission",
            rgba_to_string(mesh.material.emission)
        )

        addelement!(
            mat_elm,
            "ambiant",
            rgba_to_string(mesh.material.ambiant)
        )

        addelement!(
            mat_elm,
            "diffuse",
            rgba_to_string(mesh.material.diffuse)
        )

        addelement!(
            mat_elm,
            "specular",
            rgba_to_string(mesh.material.specular)
        )

        addelement!(
            mat_elm,
            "shininess",
            string(mesh.material.shininess)
        )
    end

    # Parsing the shapeBDD section.
    shapeBDD = addelement!(opf_elm, "shapeBDD")
    for (key, mesh) in enumerate(mtg[:ref_meshes].meshes)
        shape_elm = addelement!(shapeBDD, "shape")
        shape_elm["Id"] = key

        addelement!(
            shape_elm,
            "name",
            mesh.name
        )

        addelement!(
            shape_elm,
            "meshIndex",
            string(key)
        )

        addelement!(
            shape_elm,
            "materialIndex",
            string(key)
        )
    end

    # Parsing the attributeBDD section:
    attrBDD = addelement!(opf_elm, "attributeBDD")
    attrs = get_features(mtg)
    for i = 1:size(attrs, 1)
        shape_elm = addelement!(attrBDD, "attribute")
        shape_elm["name"] = string(attrs[i, 1])
        attr_type = attrs[i, 2]

        if attr_type == "STRING"
            attr_type_opf = "String"
        elseif attr_type == "REAL"
            attr_type_opf = "Double"
        elseif attr_type == "INT"
            attr_type_opf = "Integer"
        end

        shape_elm["class"] = attr_type_opf
    end

    # Parsing the topology section:
    mtg_topology_to_xml!(mtg, opf_elm)

    # prettyprint(doc)
    write(file, doc)
end

function rgba_to_string(x)
    join([x.r, x.g, x.b, x.alpha], "\t")
end

"""
    mtg_to_opf_link(link)

Takes an MTG link as input ("/", "<" or "+") and outputs its corresponding link as declared
in the OPF format ("decomp", "follow" or "branch")
"""
function mtg_to_opf_link(link)
    if link == "/"
        "decomp"
    elseif link == "<"
        "follow"
    elseif link == "+"
        "branch"
    end
end


"""
    mtg_topology_to_xml!(node, xml_parent)

Write the MTG topology, attributes and geometry into XML format. This function is used to
write the "topology" section of the OPF.
"""
function mtg_topology_to_xml!(node, xml_parent, ref_meshes = get_ref_meshes(node))

    if isroot(node)
        xml_parent = attributes_to_xml(node, xml_parent, ref_meshes)
    end

    if !isleaf(node)
        for chnode in MultiScaleTreeGraph.ordered_children(node)
            xml_node = attributes_to_xml(chnode, xml_parent, ref_meshes)
            mtg_topology_to_xml!(chnode, xml_node, ref_meshes)
        end
    end
end

"""
    attributes_to_xml(node, xml_parent)

Write an MTG node into an XML node.
"""
function attributes_to_xml(node, xml_parent, ref_meshes)
    opf_link = isroot(node) ? "topology" : mtg_to_opf_link(node.MTG.link)
    xml_node = addelement!(xml_parent, opf_link)
    xml_node["class"] = node.MTG.symbol
    xml_node["scale"] = node.MTG.scale
    xml_node["Id"] = node.id #! maybe this should be `node.MTG.index` instead ? But I think is is unique

    for key in keys(node.attributes)
        if key == :geometry
            geom = addelement!(xml_node, string(key))
            geom["class"] = "Mesh"

            if node[key].ref_mesh_index === nothing
                get_ref_mesh_index!(node, ref_meshes)
            end
            addelement!(geom, "shapeIndex", string(node[key].ref_mesh_index))

            addelement!(
                geom,
                "mat",
                string(
                    "\n",
                    join(node[key].transformation_matrix[1, :], "\t"),
                    "\n",
                    join(node[key].transformation_matrix[2, :], "\t"),
                    "\n",
                    join(node[key].transformation_matrix[3, :], "\t"),
                    "\n"
                )
            )
            #? NB: Only the three first rows are written as the fourth is always the same
            addelement!(geom, "dUp", string(node[key].dUp))
            addelement!(geom, "dDwn", string(node[key].dDwn))
        elseif key == :ref_meshes
            # We don't write the reference meshes here but before in the opf
            continue
        else
            addelement!(xml_node, string(key), string(node[key]))
        end
    end

    return xml_node
end
