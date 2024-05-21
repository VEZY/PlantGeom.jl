
"""
    read_ops(file; attr_type=Dict{String,Any}, mtg_type=MutableNodeMTG)

Reads an OPS file and returns the content as a `MultiScaleTreeGraph`.

# Arguments

- `file::String`: Path of the `.ops` file to read.
- `attr_type::Type=Dict{Symbol,Any}`: Type of the attributes to use.
- `mtg_type::Type`: Type of the MTG to use, e.g. `NodeMTG` or `MutableNodeMTG`.

# Returns

A `MultiScaleTreeGraph` of the scene, with the OPFs as children of the scene node. The dimension of the scene
is available in the `scene_dimensions` attribute of the scene node. Each root node of the OPFs has a `scene_transformation`
attribute that stores the transformation applied to the OPF by the scene. It allows updating the scene transformations
and write the scene back to disk. The OPF root node also has the following attributes:

- `sceneID::Int`: Scene ID.
- `plantID::Int`: Plant ID.
- `filePath::String`: Path to the original `.opf` file.
- `pos::Meshes.Point3`: Position of the object.
- `scale::Float64`: Scale of the object.
- `inclinationAzimut::Float64`: Inclination azimut of the object.
- `inclinationAngle::Float64`: Inclination angle of the object.
- `rotation::Float64`: Rotation of the object.
- `functional_group::String`: Functional group of the object.

# Details

Node IDs of the OPFs are recomputed at import to ensure their uniqueness in the larger scene MTG.

# Example

```julia
using CairoMakie, PlantGeom
joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene.ops") |> read_ops |> viz
```
"""
function read_ops(file; attr_type=Dict, mtg_type=MutableNodeMTG)
    scene = Node(mtg_type("/", "Scene", 1, 0), MultiScaleTreeGraph.init_empty_attr(attr_type))
    ops = read_ops_file(file)

    scene.scene_dimensions = ops.scene_dimensions

    max_id = Ref(0)
    ref_meshes = RefMeshes(RefMesh[])
    # Dict to store the first index of the ref_meshes in the scene.ref_meshes according to the object_table.filePath
    # Note that if several plants share the same opf, the ref_meshes will not be duplicated with this method.
    ref_meshes_length_before = Dict{String,Int}()
    #TODO: use the scene transformations (and add them to the scene node to remove them at writing).
    #TOTO: when writing the OPF back to disk, first, filter the ref_meshes to keep only the ones that are in the OPF.
    for row in Tables.rows(ops.object_table)
        opf_file = row.filePath
        opf = read_opf(joinpath(dirname(file), opf_file), attr_type=attr_type, mtg_type=mtg_type, read_id=false, max_id=max_id)

        # The first time we encounter the opf file, we store the index of the first ref_mesh in the scene.ref_meshes:
        if !haskey(ref_meshes_length_before, opf_file)
            ref_meshes_length_before[opf_file] = length(ref_meshes)
            append!(ref_meshes, opf.ref_meshes)
        end

        # Initialize the scene transformation for this OPF:
        scene_transformation = Identity()

        if row.rotation !== 0.0
            scene_transformation = scene_transformation → Rotate(RotZ(row.rotation))
        end

        if row.scale !== 1.0
            scene_transformation = scene_transformation → Scale(row.scale)
        end

        if row.inclinationAzimut !== 0.0
            @warn "InclinationAzimut is not yet implemented."
        end

        if row.inclinationAngle !== 0.0
            @warn "InclinationAngle is not yet implemented."
        end

        if row.pos !== Meshes.Point3(0.0, 0.0, 0.0)
            pos = Meshes.coordinates(row.pos) .* 100.0 # x100.0 because the scene is in m and the OPF in cm.
            scene_transformation = scene_transformation → Translate(pos...)
        end

        traverse!(opf, filter_fun=node -> !isnothing(node.geometry)) do node
            node.geometry.ref_mesh_index += ref_meshes_length_before[opf_file]
            scene_transformation != Identity() && transform_mesh!(node, scene_transformation)
        end

        opf.scene_transformation = scene_transformation
        opf.sceneID = row.sceneID
        opf.functional_group = row.functional_group
        opf.plantID = row.plantID
        opf.filePath = opf_file
        opf.pos = row.pos
        opf.scale = row.scale
        opf.inclinationAzimut = row.inclinationAzimut
        opf.inclinationAngle = row.inclinationAngle
        opf.rotation = row.rotation

        delete!(node_attributes(opf), :ref_meshes)
        addchild!(scene, opf)
    end

    scene.ref_meshes = ref_meshes

    return scene
end