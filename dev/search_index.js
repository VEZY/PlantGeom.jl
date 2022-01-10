var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = PlantGeom","category":"page"},{"location":"#PlantGeom","page":"Home","title":"PlantGeom","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for PlantGeom, a package for everything 3D in plants.","category":"page"},{"location":"#Introduction","page":"Home","title":"Introduction","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The package is designed around MultiScaleTreeGraph that serves as the basic structure for the plant topology and attributes.","category":"page"},{"location":"","page":"Home","title":"Home","text":"note: Note\n:geometry is a reserved attribute used to hold each node (e.g. organ) 3D geometry as a special structure (geometry).","category":"page"},{"location":"","page":"Home","title":"Home","text":"The package provides different functionalities, the main ones being:","category":"page"},{"location":"","page":"Home","title":"Home","text":"IO for the OPF file format (see read_opf and write_opf);\nplotting using viz and viz!, optionally using colouring by attribute;\nmesh transformations using transform_mesh!","category":"page"},{"location":"#API","page":"Home","title":"API","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [PlantGeom]","category":"page"},{"location":"#PlantGeom.Material","page":"Home","title":"PlantGeom.Material","text":"Data structure for a mesh material that is used to describe the light components of a Phong reflection type model. All data is stored as RGBα for Red, Green, Blue and transparency.\n\n\n\n\n\n","category":"type"},{"location":"#PlantGeom.RefMesh","page":"Home","title":"PlantGeom.RefMesh","text":"RefMesh type. Stores all information about a Mesh:\n\nname::S: the mesh name\nnormals::Vector{Float64}: the normals, given as a vector of x1,y1,z1,x2,y2,z2...\ntextureCoords::Vector{Float64}: the texture coordinates (not used yet), idem, a vector\nmaterial::M: the material, used to set the shading\nmesh::SimpleMesh: the actual mesh information -> points and topology\ntaper::Bool: true if tapering is enabled\n\n\n\n\n\n","category":"type"},{"location":"#PlantGeom.RefMeshes","page":"Home","title":"PlantGeom.RefMeshes","text":"RefMeshes type. Data base that stores all RefMesh in an MTG. Usually stored in the :ref_meshes attribute of the root node.\n\n\n\n\n\n","category":"type"},{"location":"#PlantGeom.geometry","page":"Home","title":"PlantGeom.geometry","text":"geometry(\n    ref_mesh::M\n    ref_mesh_index::Union{Int,Nothing}\n    transformation::T\n    dUp::S\n    dDwn::S\n    mesh::Union{SimpleMesh,Nothing}\n)\n\nA Node geometry with the reference mesh, its transformation matrix and optionnally the index of the reference mesh in the reference meshes data base (see notes) and the resulting mesh (optional to save memory).\n\nNote\n\nThe refmesh usually points to a RefMesh stored in the `:refmeshes` attribute of the root node of the MTG.\n\nAlthough optinal, storing the index of the reference mesh (ref_mesh_index) in the database allows a faster writing of the MTG as an OPF to disk.\n\nIf no transformation matrix is needed, you can use I from the Linear Algebra package (lazy)\n\nThe transformation field should a CoordinateTransformations.jl's transformation. In case no transformation is needed, use IdentityTransformation(). If you already have the transformation matrix, you can pass it to LinearMap().\n\n\n\n\n\n","category":"type"},{"location":"#MakieCore.plot!-Tuple{MakieCore.Combined{MeshViz.viz, <:Tuple{MultiScaleTreeGraph.Node}}}","page":"Home","title":"MakieCore.plot!","text":"using MultiScaleTreeGraph, PlantGeom, GLMakie\n\nfile = joinpath(dirname(dirname(pathof(PlantGeom))),\"test\",\"files\",\"simpleOPFshapes.opf\")\n\nfile = joinpath(dirname(dirname(pathof(PlantGeom))),\"test\",\"files\",\"coffee.opf\")\n\nopf = read_opf(file) viz(opf)\n\nIf you need to plot the opf several times, you better cache the mesh in the node geometry\n\nlike so:\n\ntransform!(opf, refmeshtomesh!)\n\nThen plot it again like before, and it will be faster:\n\nviz(opf)\n\nWe can also color the 3d plot with several options:\n\nWith one shared color:\n\nviz(opf, color = :red)\n\nOne color per reference mesh:\n\nviz(opf, color = Dict(1 => :burlywood4, 2 => :springgreen4, 3 => :burlywood4))\n\nOr just changing the color of some:\n\nviz(opf, color = Dict(1 => :burlywood4))\n\nOne color for each vertex of the refmesh 1:\n\nviz(opf, color = Dict(1 => 1:nvertices(getrefmeshes(opf))[1]))\n\nOr coloring by opf attribute, e.g. using the mesh max Z coordinates (NB: need to use\n\nrefmesh_to_mesh! before, see above):\n\ntransform!(opf, :geometry => (x -> zmax(x.mesh)) => :zmax, ignorenothing = true) viz(opf, color = :z_max)\n\nOr even coloring by the value of the Z coordinates of each vertex:\n\ntransform!(opf, :geometry => (x -> [i.coords[3] for i in x.mesh.points]) => :z, ignore_nothing = true) viz(opf, color = :z, showfacets = true)\n\n\n\n\n\n","category":"method"},{"location":"#MakieCore.plot!-Tuple{MakieCore.Combined{MeshViz.viz, <:Tuple{PlantGeom.RefMeshes}}}","page":"Home","title":"MakieCore.plot!","text":"using PlantGeom, GLMakie\n\nfile = joinpath(dirname(dirname(pathof(PlantGeom))),\"test\",\"files\",\"simpleOPFshapes.opf\") opf = readopf(file) meshes = getref_meshes(opf)\n\nviz(meshes)\n\nWith one shared color:\n\nviz(meshes, color = :green)\n\nOne color per reference mesh:\n\nviz(meshes, color = Dict(1 => :burlywood4, 2 => :springgreen4, 3 => :burlywood4))\n\nOr just changing the color of some:\n\nviz(meshes, color = Dict(1 => :burlywood4, 3 => :burlywood4))\n\nOne color for each vertex of the refmesh 0:\n\nviz(meshes, color = Dict(2 => 1:nvertices(meshes)[2]))\n\nColors as a vector (no missing values allowed here):\n\nviz(meshes, color = [:burlywood4, :springgreen4, :burlywood4])\n\n\n\n\n\n","category":"method"},{"location":"#Meshes.nelements-Tuple{PlantGeom.RefMeshes}","page":"Home","title":"Meshes.nelements","text":"nelements(meshes::RefMeshes)\n\nReturn the number of elements for each reference mesh as a vector of nelements\n\n\n\n\n\n","category":"method"},{"location":"#Meshes.nelements-Tuple{PlantGeom.RefMesh}","page":"Home","title":"Meshes.nelements","text":"nelements(meshes::RefMeshes)\n\nReturn the number of elements of a reference mesh\n\n\n\n\n\n","category":"method"},{"location":"#Meshes.nvertices-Tuple{PlantGeom.RefMeshes}","page":"Home","title":"Meshes.nvertices","text":"nvertices(meshes::RefMeshes)\n\nReturn the number of vertices for each reference mesh as a vector of nvertices\n\n\n\n\n\n","category":"method"},{"location":"#Meshes.nvertices-Tuple{PlantGeom.RefMesh}","page":"Home","title":"Meshes.nvertices","text":"nvertices(meshes::RefMesh)\n\nReturn the number of vertices of a reference mesh\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.align_ref_meshes-Tuple{PlantGeom.RefMeshes}","page":"Home","title":"PlantGeom.align_ref_meshes","text":"align_ref_meshes(meshes::RefMeshes)\n\nAlign all reference meshes along the X axis. Used for visualisation only.\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.attributes_to_xml-Tuple{Any, Any, Any}","page":"Home","title":"PlantGeom.attributes_to_xml","text":"attributes_to_xml(node, xml_parent)\n\nWrite an MTG node into an XML node.\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.get_attr_type-Tuple{Any}","page":"Home","title":"PlantGeom.get_attr_type","text":"Get the attributes types in Julia DataType.\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.get_ref_mesh_index","page":"Home","title":"PlantGeom.get_ref_mesh_index","text":"get_ref_mesh_index!(node, ref_meshes = get_ref_meshes(node))\nget_ref_mesh_index(node, ref_meshes = get_ref_meshes(node))\n\nGet the index of the reference mesh used in the current node.\n\nNotes\n\nPlease use the ref_meshes argument preferably as not giving it make the function visit the root node each time otherwise, and it can become a limitation when traversing a big MTG.\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.get_ref_mesh_index!","page":"Home","title":"PlantGeom.get_ref_mesh_index!","text":"get_ref_mesh_index!(node, ref_meshes = get_ref_meshes(node))\nget_ref_mesh_index(node, ref_meshes = get_ref_meshes(node))\n\nGet the index of the reference mesh used in the current node.\n\nNotes\n\nPlease use the ref_meshes argument preferably as not giving it make the function visit the root node each time otherwise, and it can become a limitation when traversing a big MTG.\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.get_ref_meshes-Tuple{Any}","page":"Home","title":"PlantGeom.get_ref_meshes","text":"get_ref_meshes(mtg)\n\nGet all reference meshes from an mtg, usually from an OPF.\n\nExamples\n\nusing PlantGeom\nfile = joinpath(dirname(dirname(pathof(PlantGeom))),\"test\",\"files\",\"simple_OPF_shapes.opf\")\nopf = read_opf(file)\nmeshes = get_ref_meshes(opf)\n\nusing GLMakie\nviz(meshes)\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.get_ref_meshes_color-Tuple{PlantGeom.RefMeshes}","page":"Home","title":"PlantGeom.get_ref_meshes_color","text":"get_ref_meshes_color(meshes::RefMeshes)\n\nGet the reference meshes colors (only the diffuse part for now).\n\nExamples\n\nusing MultiScaleTreeGraph, PlantGeom\nfile = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),\"test\",\"files\",\"simple_OPF_shapes.opf\")\nopf = read_opf(file)\nmeshes = get_ref_meshes(opf)\nPlantGeom.get_ref_meshes_color(meshes)\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.map_coord-Tuple{Any, Any, Any}","page":"Home","title":"PlantGeom.map_coord","text":"map_coord(f, mesh, coord)\n\nApply function f over the mesh coordinates coord. Values for coord can be 1 for x, 2 for y and 3 for z.\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.materialBDD_to_material-Tuple{Any}","page":"Home","title":"PlantGeom.materialBDD_to_material","text":"Parse a material in opf format to a material\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.meshBDD_to_meshes-Tuple{Any}","page":"Home","title":"PlantGeom.meshBDD_to_meshes","text":"meshBDD_to_meshes(x)\n\nExamples\n\nusing MultiScaleTreeGraph\nfile = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),\"test\",\"files\",\"simple_OPF_shapes.opf\")\nopf = read_opf(file)\nmeshBDD_to_meshes(opf.attributes[:meshBDD])\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.mtg_to_opf_link-Tuple{Any}","page":"Home","title":"PlantGeom.mtg_to_opf_link","text":"mtg_to_opf_link(link)\n\nTakes an MTG link as input (\"/\", \"<\" or \"+\") and outputs its corresponding link as declared in the OPF format (\"decomp\", \"follow\" or \"branch\")\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.mtg_topology_to_xml!","page":"Home","title":"PlantGeom.mtg_topology_to_xml!","text":"mtg_topology_to_xml!(node, xml_parent)\n\nWrite the MTG topology, attributes and geometry into XML format. This function is used to write the \"topology\" section of the OPF.\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.parse_geometry-Tuple{Any}","page":"Home","title":"PlantGeom.parse_geometry","text":"Parse the geometry element of the OPF.\n\nNote\n\nThe transformation matrix is 3*4. elem = elem.content\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.parse_materialBDD!-Tuple{Any}","page":"Home","title":"PlantGeom.parse_materialBDD!","text":"Parse the materialBDD using parse_opf_elements!\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.parse_meshBDD!-Tuple{Any}","page":"Home","title":"PlantGeom.parse_meshBDD!","text":"Parse the meshBDD using parse_opf_array\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.parse_opf_array","page":"Home","title":"PlantGeom.parse_opf_array","text":"Parse an array of values from the OPF into a Julia array (Arrays in OPFs are not following XML recommendations)\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.parse_opf_attributeBDD!-Tuple{Any}","page":"Home","title":"PlantGeom.parse_opf_attributeBDD!","text":"Parse the opf attributes as a Dict.\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.parse_opf_elements!-Tuple{Any, Any}","page":"Home","title":"PlantGeom.parse_opf_elements!","text":"Generic parser for OPF elements.\n\nArguments\n\nopf::OrderedDict: the opf Dict (using [XMLDict.xml_dict])\nelem_types::Array: the target types of the element (e.g. \"[String, Int64]\")\n\nDetails\n\nelem_types should be of the same length as the number of elements found in each item of the subchild. elem_types = [Float64, Float64, Float64, Float64, Float64, Float64]\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.parse_opf_topology!","page":"Home","title":"PlantGeom.parse_opf_topology!","text":"Parser for OPF topology.\n\nNote\n\nThe transformation matrices in geometry are 3*4. parseopftopology!(elem, nodei, features) node = elem mtg = nodei features = getattrtype(opf_attr[:attributeBDD])\n\nDebugging:\n\nmtg = nothing\n\nnode = elem mtg = nodei parseopftopology!(                 node,                 nothing,                 getattrtype(opfattr[:attributeBDD]),                 attrtype,                 mtgtype,                 ref_meshes             )\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.parse_ref_meshes-Tuple{Any}","page":"Home","title":"PlantGeom.parse_ref_meshes","text":"parse_ref_meshes(mtg)\n\nParse the reference meshes of an OPF into RefMeshes.\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.read_opf","page":"Home","title":"PlantGeom.read_opf","text":"read_opf(file, attr_type = Dict, mtg_type = MutableNodeMTG)\n\nRead an OPF file, and returns an MTG.\n\nArguments\n\nfile::String: The path to the opf file.\nattr_type::DataType = Dict: the type used to hold the attribute values for each node.\nmtg_type = MutableNodeMTG: the type used to hold the mtg encoding for each node (i.e.\n\nlink, symbol, index, scale). See details section below.\n\nDetails\n\nattr_type should be:\n\nNamedTuple if you don't plan to modify the attributes of the mtg, e.g. to use them for\n\nplotting or computing statistics...\n\nMutableNamedTuple if you plan to modify the attributes values but not adding new attributes\n\nvery often, e.g. recompute an attribute value...\n\nDict or similar (e.g. OrderedDict) if you plan to heavily modify the attributes, e.g.\n\nadding/removing attributes a lot\n\nThe MultiScaleTreeGraph package provides two types for mtg_type, one immutable (NodeMTG), and one mutable (MutableNodeMTG). If you're planning on modifying the mtg encoding of some of your nodes, you should use MutableNodeMTG, and if you don't want to modify anything, use NodeMTG instead as it should be faster.\n\nNote\n\nSee the documentation of the MTG format from the package documentation for further details, e.g. The MTG concept.\n\nReturns\n\nThe MTG root node.\n\nExamples\n\nusing PlantGeom\nfile = joinpath(dirname(dirname(pathof(PlantGeom))),\"test\",\"files\",\"simple_OPF_shapes.opf\")\nopf = read_opf(file)\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.refmesh_to_mesh","page":"Home","title":"PlantGeom.refmesh_to_mesh","text":"refmesh_to_mesh!(node)\nrefmesh_to_mesh(node)\n\nCompute a node mesh based on the reference mesh, the transformation matrix and the tapering. The mutating version adds the new mesh to the mesh field of the geometry attribute of the node.\n\nExamples\n\nusing PlantGeom\nfile = joinpath(dirname(dirname(pathof(PlantGeom))),\"test\",\"files\",\"simple_OPF_shapes.opf\")\nopf = read_opf(file)\n\nnode = opf[1][1][1]\n\nnew_mesh = refmesh_to_mesh(node)\n\nusing MeshViz, GLMakie\nviz(new_mesh)\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.refmesh_to_mesh!","page":"Home","title":"PlantGeom.refmesh_to_mesh!","text":"refmesh_to_mesh!(node)\nrefmesh_to_mesh(node)\n\nCompute a node mesh based on the reference mesh, the transformation matrix and the tapering. The mutating version adds the new mesh to the mesh field of the geometry attribute of the node.\n\nExamples\n\nusing PlantGeom\nfile = joinpath(dirname(dirname(pathof(PlantGeom))),\"test\",\"files\",\"simple_OPF_shapes.opf\")\nopf = read_opf(file)\n\nnode = opf[1][1][1]\n\nnew_mesh = refmesh_to_mesh(node)\n\nusing MeshViz, GLMakie\nviz(new_mesh)\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.taper-Tuple{Any, Any, Any}","page":"Home","title":"PlantGeom.taper","text":"Returns a tapered mesh using dDwn and dUp based on the geometry of an input mesh. Tapering a mesh transforms it into a tapered version (i.e. pointy) or enlarged object, e.g. make a cone from a cylinder.\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.transform_mesh!-Tuple{MultiScaleTreeGraph.Node, Any}","page":"Home","title":"PlantGeom.transform_mesh!","text":"transform_mesh!(node::Node, transformation)\n\nAdd a new CoordinateTransformations.jl transformation to the node geometry transformation field. The transformation is composed with the previous transformation if any.\n\ntransformation must be a CoordinateTransformations.jl transformation.\n\nIt is also possible to invert a transformation using inv from CoordinateTransformations.jl.\n\nExamples\n\nusing PlantGeom, MultiScaleTreeGraph, GLMakie, Rotations, CoordinateTransformations\n\nfile = joinpath(dirname(dirname(pathof(PlantGeom))), \"test\", \"files\", \"simple_OPF_shapes.opf\")\nopf = read_opf(file)\n\n# Visualize the mesh as is:\nviz(opf)\n\n# Copy the OPF, and translate the whole plant by 15 in the y direction (this is in cm, the mesh comes from XPlo):\nopf2 = deepcopy(opf)\ntransform!(opf2, x -> transform_mesh!(x, Translation(0, 15, 0)))\nviz!(opf2) # Visualize it again in the same figure\n\n# Same but rotate the whole plant around the X axis:\nopf3 = deepcopy(opf)\ntransform!(opf3, x -> transform_mesh!(x, LinearMap(RotX(0.3))))\n# NB: we use Rotations.jl's RotX here. Input in radian, use rad2deg and deg2rad if needed.\nviz!(opf3)\n\n# Same but rotate only the second leaf around the Z axis:\nopf4 = deepcopy(opf)\n# Build the meshes from the reference meshes (need it because we want the coordinates of the parent):\ntransform!(opf4, refmesh_to_mesh!)\n\n# Get the second leaf in the OPF:\nleaf_node = get_node(opf4, 8)\n\n# Get the parent node (internode) Z coordinates:\nparent_zmax = zmax(leaf_node.parent)\n\n# Define a rotation of the mesh around the Z axis defined by the parent node max Z:\ntransformation = recenter(LinearMap(RotZ(1.0)), Point3(0.0, 0.0, parent_zmax))\n\n# Update the transformation matrix of the leaf and its mesh:\ntransform_mesh!(leaf_node, transformation)\n\n# Plot the result:\nviz(opf)\nviz!(opf4)\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.write_opf-Tuple{Any, Any}","page":"Home","title":"PlantGeom.write_opf","text":"write_opf(opf, file)\n\nWrite an MTG with explicit geometry to disk as an OPF file.\n\nNotes\n\nNode attributes :mesh, :ref_meshes and :geometry are treated as reserved keywords and should not be used without knowing their meaning:\n\n:ref_meshes: a RefMeshes structure that holds the MTG reference meshes.\n:geometry: a Dict of four:\n:shapeIndex: the index of the node reference mesh\n:dUp: tappering in the upper direction\n:dDwn: tappering in the bottom direction\n:mat: the transformation matrix (4x4)\n:mesh: a SimpleMesh computed from a reference mesh (:ref_meshes) and a transformation\n\nmatrix (:geometry).\n\nExamples\n\nusing PlantGeom\nfile = joinpath(dirname(dirname(pathof(PlantGeom))),\"test\",\"files\",\"simple_OPF_shapes.opf\")\nopf = read_opf(file)\n\nwrite_opf(\"test.opf\", opf)\nfile = \"test.opf\"\nopf2 = read_opf(file)\nviz(opf2)\n\n\n\n\n\n","category":"method"},{"location":"#PlantGeom.xmax","page":"Home","title":"PlantGeom.xmax","text":"xmax(x)\nymax(x)\nzmax(x)\n\nGet the maximum x, y or z coordinates of a mesh or a Node.\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.xmin","page":"Home","title":"PlantGeom.xmin","text":"xmin(x)\nymin(x)\nzmin(x)\n\nGet the minimum x, y or z coordinates of a mesh or a Node.\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.ymax","page":"Home","title":"PlantGeom.ymax","text":"xmax(x)\nymax(x)\nzmax(x)\n\nGet the maximum x, y or z coordinates of a mesh or a Node.\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.ymin","page":"Home","title":"PlantGeom.ymin","text":"xmin(x)\nymin(x)\nzmin(x)\n\nGet the minimum x, y or z coordinates of a mesh or a Node.\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.zmax","page":"Home","title":"PlantGeom.zmax","text":"xmax(x)\nymax(x)\nzmax(x)\n\nGet the maximum x, y or z coordinates of a mesh or a Node.\n\n\n\n\n\n","category":"function"},{"location":"#PlantGeom.zmin","page":"Home","title":"PlantGeom.zmin","text":"xmin(x)\nymin(x)\nzmin(x)\n\nGet the minimum x, y or z coordinates of a mesh or a Node.\n\n\n\n\n\n","category":"function"}]
}
