
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
- `pos::Meshes.Point`: Position of the object.
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
    scene_dimensions, object_table = read_ops_file(file)

    scene = Node(mtg_type("/", "Scene", 1, 0), MultiScaleTreeGraph.init_empty_attr(attr_type))
    scene.scene_dimensions = scene_dimensions

    node_max_id = Ref(0)

    # Reading all the OPF files, but only once if they are used several times in the scene.
    # If they do, we make a deep copy of the original OPF:
    opfs = Node[]
    opf_orig_position = Dict{String,Int}()
    for row in Tables.rows(object_table)
        opf_file = row.filePath
        # If the OPF has not been copied yet, we use it as is, else we make a new one based on a copy of the original:
        if haskey(opf_orig_position, opf_file)
            opf = deepcopy(opfs[opf_orig_position[opf_file]])
            traverse!(opf) do node
                setfield!(node, :id, node_max_id[])
                node_max_id[] += 1
            end
            push!(opfs, opf)
        else
            opf = read_opf(joinpath(dirname(file), opf_file), attr_type=attr_type, mtg_type=mtg_type, read_id=false, max_id=node_max_id)
            delete!(node_attributes(opf), :ref_meshes)
            push!(opfs, opf)
            opf_orig_position[opf_file] = length(opfs)
        end
    end
    #! Important: we need to do this before the code below, because we need the OPFs without transformations first.

    for (i, row) in enumerate(Tables.rows(object_table))
        opf = opfs[i]

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

        if row.pos !== Meshes.Point(0.0, 0.0, 0.0)
            pos = Unitful.uconvert.(u"cm", Meshes.to(row.pos)) # the OPF is in cm.
            scene_transformation = scene_transformation → Translate(pos...)
        end

        traverse!(opf, filter_fun=node -> !isnothing(node.geometry)) do node
            scene_transformation != Identity() && transform_mesh!(node, scene_transformation)
        end

        opf.scene_transformation = scene_transformation
        opf.sceneID = row.sceneID
        opf.functional_group = row.functional_group
        opf.plantID = row.plantID
        opf.filePath = row.filePath
        opf.pos = row.pos
        opf.scale = row.scale
        opf.inclinationAzimut = row.inclinationAzimut
        opf.inclinationAngle = row.inclinationAngle
        opf.rotation = row.rotation
        addchild!(scene, opf)
    end

    # Add the scene quadrangle to the scene:
    p_0 = Unitful.uconvert.(u"cm", Meshes.to(scene_dimensions[1])) # m (scene) to cm (OPF)
    p_max = Unitful.uconvert.(u"cm", Meshes.to(scene_dimensions[2]))

    p = Meshes.Point.([(p_0...,), (p_max[1], p_0[2], p_0[3]), (p_max...,), (p_0[1], p_max[2], p_0[3])])
    c = Meshes.connect.([(1, 2, 3), (3, 4, 1)])
    scene_quadrangle = Meshes.SimpleMesh(p, c)

    # Note: could also used `Meshes.Quadrangle` but then we need to discretize it.
    scene_refmesh = RefMesh("Scene", scene_quadrangle, RGBA(159 / 255, 182 / 255, 205 / 255, 0.1))
    scene.geometry = Geometry(ref_mesh=scene_refmesh)
    # push!(ref_meshes, scene_refmesh)
    # scene.ref_meshes = ref_meshes

    return scene
end