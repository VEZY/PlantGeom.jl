"""
    write_opf(opf, file)

Write an MTG with explicit geometry to disk as an OPF file.

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
opf = read_opf(file)

write_opf(opf, "test.opf")
```
"""
function write_opf(opf, file)
    doc = XMLDocument()
    opf_elm = ElementNode("opf")
    setroot!(doc, opf_elm)
    opf_elm["version"] = 2.0
    opf_elm["editable"] = true

    # Writing the reference meshes (meshBDD):
    meshBDD = addelement!(opf_elm, "meshBDD")

    for (key, mesh) in opf[:ref_meshes].meshes
        # key = 0; mesh = opf[:ref_meshes].meshes[key]
        mesh_elm = addelement!(meshBDD, "mesh")
        mesh_elm["name"] = ""
        mesh_elm["shape"] = ""
        mesh_elm["Id"] = key
        mesh_elm["enableScale"] = true

        points_elm = addelement!(
            mesh_elm,
            "points",
            join([vcat([p.coords for p in mesh.mesh.points]...)...], " ")
        )

        norm_elm = addelement!(
            mesh_elm,
            "normals",
            join(mesh.normals, " ")
        )

        norm_elm = addelement!(
            mesh_elm,
            "textureCoords",
            join(mesh.textureCoords, " ")
        )

        faces_elm = addelement!(mesh_elm, "faces")

        face_id = [0]
        for i = 1:nelements(mesh.mesh.topology)
            face_elm = addelement!(
                faces_elm,
                "face",
                join(mesh.mesh.topology.connec[i].indices, " ")
            )
            face_elm["Id"] = face_id[1]
            face_id[1] = face_id[1] + 1
        end

    end

    # Parsing the materialBDD section.
    #! NB: the materials should be unique and not repeated
    #! for each mesh. The mesh should only reference a material.
    #! Change that when reading and writing opf
    materialBDD = addelement!(opf_elm, "materialBDD")
    for (key, mesh) in opf[:ref_meshes].meshes
        mat_elm = addelement!(materialBDD, "material")
        mat_elm["Id"] = key

        e_elm = addelement!(
            mat_elm,
            "emission",
            rgba_to_string(mesh.material.emission)
        )

        a_elm = addelement!(
            mat_elm,
            "ambiant",
            rgba_to_string(mesh.material.ambiant)
        )

        d_elm = addelement!(
            mat_elm,
            "diffuse",
            rgba_to_string(mesh.material.diffuse)
        )

        s_elm = addelement!(
            mat_elm,
            "specular",
            rgba_to_string(mesh.material.specular)
        )

        sh_elm = addelement!(
            mat_elm,
            "shininess",
            string(mesh.material.shininess)
        )
    end


    # Parsing the shapeBDD section.
    shapeBDD = addelement!(opf_elm, "shapeBDD")
    for (key, mesh) in opf[:ref_meshes].meshes
        shape_elm = addelement!(shapeBDD, "shape")
        shape_elm["Id"] = key


        name_elm = addelement!(
            shape_elm,
            "name",
            mesh.name
        )

        meshIndex = addelement!(
            shape_elm,
            "meshIndex",
            string(key)
        )

        #! NB: here we should only reference the material (see above):
        matIndex = addelement!(
            shape_elm,
            "materialIndex",
            string(key)
        )
    end

    # Parsing the attributeBDD section:
    attrBDD = addelement!(opf_elm, "attributeBDD")
    attrs = get_features(opf)
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

        attr_type["class"] = attr_type_opf
    end

    # Parsing the attributeBDD section:
    topo = addelement!(opf_elm, "topology")
    topo["class"] = "Scene"
    topo["scale"] = 0
    topo["Id"] = 0

    traverse!(opf) do node

        node_i = addelement!(opf_elm, mtg_to_opf_link(node.MTG.link))
        #! continue here!!
    end

    # link!(elm, txt)
    # addelement!(user, "name", "Kumiko Oumae")

    prettyprint(doc)


end

function rgba_to_string(x)
    join([x.r, x.g, x.b, x.alpha], " ")
end

function mtg_to_opf_link(link)
    if link == "/"
        "decomp"
    elseif link == "<"
        "follow"
    elseif link == "+"
        "branch"
    end
end
