"""
    write_gwa(file, mtg)

Write an MTG object to disk as a GWA mesh file.
"""
function write_gwa(file, mtg)
    root = isroot(mtg) ? mtg : get_root(mtg)
    clean_cache!(root)

    doc = XMLDocument()
    gwa_elm = ElementNode("gwa")
    setroot!(doc, gwa_elm)
    gwa_elm["version"] = "1.0"

    attrs_elm = addelement!(gwa_elm, "attributes")
    attr_elm = addelement!(attrs_elm, "attribute")
    attr_elm["name"] = "Color"
    attr_elm["class"] = "Color"

    mesh_nodes = MultiScaleTreeGraph.traverse(
        root,
        node -> node,
        filter_fun=node -> !isroot(node) && has_geometry(node),
        type=typeof(root)
    )

    for node in mesh_nodes
        mesh_elm = addelement!(gwa_elm, "mesh")
        mesh_elm["id"] = hasproperty(node, :source_topology_id) ? node.source_topology_id : node_id(node)
        mesh_elm["label"] = node[:geometry].ref_mesh.name

        mesh = refmesh_to_mesh(node)
        points_flat = Iterators.flatten((p[1], p[2], p[3]) for p in _vertices(mesh))
        addelement!(mesh_elm, "points", string("\n\t\t\t", join(points_flat, "\t"), "\n\t\t"))

        normals_flat = Iterators.flatten((n[1], n[2], n[3]) for n in normals_vertex(mesh))
        addelement!(mesh_elm, "normals", string("\n\t\t\t", join(normals_flat, "\t"), "\n\t\t"))

        faces_elm = addelement!(mesh_elm, "faces")
        face_id = 0
        for tri in _faces(mesh)
            face_elm = addelement!(faces_elm, "face", string("\n\t\t\t\t", tri[1] - 1, "\t", tri[2] - 1, "\t", tri[3] - 1, "\n\t\t\t"))
            face_elm["Id"] = face_id
            face_id += 1
        end

        color = RGB(material_single_color(node[:geometry].ref_mesh.material))
        r = round(Int, 255 * Float64(color.r))
        g = round(Int, 255 * Float64(color.g))
        b = round(Int, 255 * Float64(color.b))
        addelement!(mesh_elm, "Color", "Color $r $g $b")
    end

    write(file, doc)
    return file
end
