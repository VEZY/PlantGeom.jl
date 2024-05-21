"""
    write_opf(file, opf)

Write an MTG with explicit geometry to disk as an OPF file.

# Notes

Node attributes `:ref_meshes` and `:geometry` are treated as reserved keywords and
should not be used without knowing their meaning:

- `:ref_meshes`: a `RefMeshes` structure that holds the MTG reference meshes.
- `:geometry`: a [`geometry`](@ref) instance

# Examples

```julia
using PlantGeom
file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")
opf = read_opf(file)
write_opf("test.opf", opf)
opf2 = read_opf("test.opf")
viz(opf2)
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

    for (key, mesh_) in enumerate(mtg[:ref_meshes].meshes)
        # key = 1; mesh_ = mtg[:ref_meshes].meshes[key]
        mesh_elm = addelement!(meshBDD, "mesh")
        mesh_elm["name"] = mesh_.name
        mesh_elm["shape"] = ""
        mesh_elm["Id"] = key - 1 # opf uses 0-based indexing
        mesh_elm["enableScale"] = mesh_.taper

        addelement!(
            mesh_elm,
            "points",
            string("\n", join(Iterators.flatten(Meshes.coordinates(p) for p in Meshes.vertices(mesh_.mesh)), "\t"), "\n")
        )

        if length(mesh_.normals) == Meshes.nelements(mesh_) && length(mesh_.normals) != Meshes.nvertices(mesh_)
            # If the normals are per triangle, re-compute them per vertex:
            vertex_normals = normals_vertex(mesh_)
        else
            vertex_normals = mesh_.normals
        end

        norm_elm = addelement!(
            mesh_elm,
            "normals",
            # string("\n", join(reduce(vcat, [Meshes.coordinates(p) for p in vertex_normals]), "\t"), "\n")
            string("\n", join(Iterators.flatten(Meshes.coordinates(p) for p in vertex_normals), "\t"), "\n")
        )


        if mesh_.texture_coords !== nothing && length(mesh_.texture_coords) > 0
            # texture_coords are optional
            norm_elm = addelement!(
                mesh_elm,
                "textureCoords",
                string("\n", join(Iterators.flatten(Meshes.coordinates(p) for p in mesh_.texture_coords), "\t"), "\n")
            )
        end

        faces_elm = addelement!(mesh_elm, "faces")

        face_id = [0]
        for i in firstindex(mesh_.mesh):lastindex(mesh_.mesh)
            face_elm = addelement!(
                faces_elm,
                "face",
                string("\n", join(Meshes.topology(mesh_.mesh).connec[i].indices .- 1, "\t"), "\n")
            )
            #? NB: we remove one because face index are 0-based in the opf
            face_elm["Id"] = face_id[1]
            face_id[1] = face_id[1] + 1
        end
    end

    # Parsing the materialBDD section.
    materialBDD = addelement!(opf_elm, "materialBDD")
    for (key, mesh_) in enumerate(mtg[:ref_meshes].meshes)
        mat_elm = addelement!(materialBDD, "material")
        mat_elm["Id"] = key - 1 # opf uses 0-based indexing

        mat = material_to_opf_string(mesh_.material)
        addelement!(
            mat_elm,
            "emission",
            mat[:emission]
        )

        addelement!(
            mat_elm,
            "ambient",
            mat[:ambient]
        )

        addelement!(
            mat_elm,
            "diffuse",
            mat[:diffuse]
        )

        addelement!(
            mat_elm,
            "specular",
            mat[:specular]
        )

        addelement!(
            mat_elm,
            "shininess",
            mat[:shininess]
        )
    end

    # Parsing the shapeBDD section.
    shapeBDD = addelement!(opf_elm, "shapeBDD")
    for (key, mesh_) in enumerate(mtg[:ref_meshes].meshes)
        shape_elm = addelement!(shapeBDD, "shape")
        shape_elm["Id"] = key - 1 # opf uses 0-based indexing

        addelement!(
            shape_elm,
            "name",
            mesh_.name
        )

        addelement!(
            shape_elm,
            "meshIndex",
            string(key - 1)
        )

        addelement!(
            shape_elm,
            "materialIndex",
            string(key - 1)
        )
    end

    # Parsing the attributeBDD section:
    attrBDD = addelement!(opf_elm, "attributeBDD")
    attrs = unique(MultiScaleTreeGraph.get_features(mtg))
    for row in eachrow(attrs)
        (string(row.NAME) == "ref_meshes" || string(row.NAME) == "geometry") && continue

        shape_elm = addelement!(attrBDD, "attribute")
        shape_elm["name"] = string(row.NAME)
        attr_type = row.TYPE

        if attr_type == "STRING" # Type in the MTG
            attr_type_opf = "String" # Type in the OPF
        elseif attr_type == "REAL"
            attr_type_opf = "Double"
        elseif attr_type == "INT"
            attr_type_opf = "Integer"
        elseif attr_type == "BOOLEAN"
            attr_type_opf = "Boolean"
        else
            error("Unknown attribute type: $(attr_type) for attribute $(row.NAME)")
        end

        shape_elm["class"] = attr_type_opf
    end

    # Parsing the topology section:
    mtg_topology_to_xml!(mtg, opf_elm)

    # prettyprint(doc)
    write(file, doc)
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

    xml_node["class"] = symbol(node)
    xml_node["scale"] = scale(node)
    xml_node["id"] = node_id(node)

    for key in keys(node)
        if key == :geometry
            geom = addelement!(xml_node, string(key))
            geom["class"] = "Mesh"

            if node[key].ref_mesh_index === nothing
                get_ref_mesh_index!(node, ref_meshes)
            end
            addelement!(geom, "shapeIndex", string(node[key].ref_mesh_index - 1))
            # NB: opf uses 0-based indexing, that's why we use ref_mesh_index - 1

            # Make the homogeneous matrix from the transformations:

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

function get_transformation_matrix(trans)
    error("Transformation type not supported: $(typeof(trans)). Please implement a new method to get the matrix out of this type of transformation.")
end

function get_transformation_matrix(::T) where {T<:UniformScaling}
    Matrix{Float64}(I, 4, 4)
end

function get_transformation_matrix(::Identity)
    Matrix{Float64}(I, 4, 4)
end

#! This was used to write CoordinateTransformations transformation matrices that had linear+translation 
# function get_transformation_matrix(trans)
#     hcat(trans.linear, trans.translation)
# end

function get_transformation_matrix(trans::Affine)
    A, b = parameters(trans)
    vcat(hcat(A, b), [0 0 0 1])
end

function get_transformation_matrix(trans::Translate{D,T}) where {D,T}
    [1.0 0.0 0.0 trans.offsets[1]; 0.0 1.0 0.0 trans.offsets[2]; 0.0 0.0 1.0 trans.offsets[3]; 0.0 0.0 0.0 1.0]
end

function get_transformation_matrix(trans::Rotate{T}) where {T<:Rotation}
    vcat(hcat(trans.rot, [0 0 0]), [0 0 0 1])
end

function get_transformation_matrix(trans::Scale{D,T}) where {D,T}
    Diagonal([trans.factors..., 1.0])
end

function get_transformation_matrix(trans::ComposedFunction)
    get_transformation_matrix(trans.outer) * get_transformation_matrix(trans.inner)
end