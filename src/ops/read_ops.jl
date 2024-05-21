
"""
    read_ops(file; attr_type=Dict{String,Any}, mtg_type=MutableNodeMTG)

Reads an OPS file and returns the content as a `MultiScaleTreeGraph`.

# Arguments

- `file::String`: Path of the `.ops` file to read.
- `attr_type::Type=Dict{Symbol,Any}`: Type of the attributes to use.
- `mtg_type::Type`: Type of the MTG to use, e.g. `NodeMTG` or `MutableNodeMTG`.

# Returns

A `MultiScaleTreeGraph`.

# Details

Node IDs of the OPFs are recomputed at import to ensure their uniqueness in the larger scene MTG.

# Example

```julia
using CairoMakie, PlantGeom
file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene.ops")

scene = read_ops(file)
viz(scene)
```
"""
function read_ops(file; attr_type=Dict, mtg_type=MutableNodeMTG)
    ops = read_ops_file(file)
    object_table = Tables.columntable(ops.object_table)
    scene = Node(mtg_type("/", "Scene", 1, 0), MultiScaleTreeGraph.init_empty_attr(attr_type))
    max_id = Ref(0)
    ref_meshes = RefMeshes(RefMesh[])
    # Dict to store the first index of the ref_meshes in the scene.ref_meshes according to the object_table.filePath
    # Note that if several plants share the same opf, the ref_meshes will not be duplicated with this method.
    ref_meshes_length_before = Dict{String,Int}()
    #TODO: use the scene transformations (and add them to the scene node to remove them at writing).
    #TOTO: when writing the OPF back to disk, first, filter the ref_meshes to keep only the ones that are in the OPF.
    for obj in object_table.filePath # obj = object_table.filePath[1]
        opf = read_opf(joinpath(dirname(file), obj), attr_type=attr_type, mtg_type=mtg_type, read_id=false, max_id=max_id)

        # The first time we encounter the opf file, we store the index of the first ref_mesh in the scene.ref_meshes:
        if !haskey(ref_meshes_length_before, obj)
            ref_meshes_length_before[obj] = length(ref_meshes)
            append!(ref_meshes, opf.ref_meshes)
        end
        traverse!(opf, filter_fun=node -> !isnothing(node.geometry)) do node
            node.geometry.ref_mesh_index += ref_meshes_length_before[obj]
        end
        addchild!(scene, opf)
    end

    scene.ref_meshes = ref_meshes

    return scene
end