"""
    read_gwa(file; attr_type=Dict, mtg_type=MutableNodeMTG, read_id=true, max_id=Ref(1))

Read a GWA mesh file and return a `MultiScaleTreeGraph.Node`.

`attr_type` is kept for backward compatibility and ignored with
MultiScaleTreeGraph >= v0.15 (columnar attributes backend).
"""

@inline function _xml_attr(node, key, default="")
    try
        v = node[key]
        v === nothing || isempty(string(v)) ? default : string(v)
    catch
        default
    end
end

function read_gwa(file; attr_type=Dict, mtg_type=MultiScaleTreeGraph.MutableNodeMTG, read_id=true, max_id=Ref(1))
    doc = readxml(file)
    xroot = root(doc)

    xroot.name == "gwa" || error("The file is not a GWA")

    root_id = if read_id
        1
    else
        id = max_id[]
        max_id[] += 1
        id
    end
    mtg = Node(mtg_type(:/, :GWA, root_id, 0), MultiScaleTreeGraph.init_empty_attr())

    ref_meshes = RefMesh[]
    for mesh_node in eachelement(xroot)
        mesh_node.name == "mesh" || continue

        mesh_label = _xml_attr(mesh_node, "label", "mesh$(length(ref_meshes) + 1)")
        mesh_id_raw = parse(Int, _xml_attr(mesh_node, "id", string(length(ref_meshes))))

        points = GeometryBasics.Point{3,Float64}[]
        faces = Face3[]
        color = RGB(220 / 255, 220 / 255, 220 / 255)

        for child in eachelement(mesh_node)
            if child.name == "points"
                vals = parse.(Float64, split(strip(child.content)))
                length(vals) % 3 == 0 || error("Invalid point array in GWA file $file")
                points = [point3(vals[i], vals[i + 1], vals[i + 2]) for i in 1:3:length(vals)]
            elseif child.name == "faces"
                for face_node in eachelement(child)
                    face_node.name == "face" || continue
                    face_vals = parse.(Int, split(strip(face_node.content)))
                    length(face_vals) == 3 || error("Invalid face in GWA file $file")
                    push!(faces, face3(face_vals[1] + 1, face_vals[2] + 1, face_vals[3] + 1))
                end
            elseif lowercase(child.name) == "color"
                nums = [parse(Float64, m.match) for m in eachmatch(r"[+-]?\d*\.?\d+", child.content)]
                if length(nums) >= 3
                    r, g, b = nums[1], nums[2], nums[3]
                    if max(r, g, b) > 1.0
                        r /= 255.0
                        g /= 255.0
                        b /= 255.0
                    end
                    color = RGB(clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(b, 0.0, 1.0))
                end
            end
        end

        isempty(points) && error("No points found in GWA mesh '$mesh_label' from file $file")
        isempty(faces) && error("No faces found in GWA mesh '$mesh_label' from file $file")

        ref_mesh = RefMesh(mesh_label, _mesh(points, faces), color)
        push!(ref_meshes, ref_mesh)

        node_id = if read_id
            mesh_id_raw + 1
        else
            id = max_id[]
            max_id[] += 1
            id
        end

        node = Node(mtg_type(:+, :Mesh, node_id, 1), MultiScaleTreeGraph.init_empty_attr())
        node.geometry = Geometry(ref_mesh=ref_mesh)
        addchild!(mtg, node)
    end

    isempty(ref_meshes) && error("No <mesh> element found in GWA file $file")
    mtg[:ref_meshes] = ref_meshes

    return mtg
end
