
"""
    write_ops(file, scene_dimensions, object_table)

Write a scene file (`.ops`), with the given dimensions and object table.

# Arguments

- `file::String`: Path of the `.ops` file to write.
- `scene_dimensions::Tuple{Meshes.Point{3,T},Meshes.Point{3,T}}`: Dimensions of the scene.
- `object_table`: Table with the objects to write in the `.ops` file. The table may have the following columns:
    - `sceneID::Int`: Scene ID (mandatory).
    - `plantID::Int`: Plant ID (mandatory).
    - `filePath::String`: Path to the `.opf` file (mandatory).
    - `pos::Meshes.Point{3,T}`: Position of the object (mandatory).
    - `functional_group::String`: Functional group of the object, used to map the object to the models (mandatory).
    - `scale::T`: Scale of the object (optional, 0.0 as default).
    - `inclinationAzimut::T`: Inclination azimut of the object (optional, 0.0 as default).
    - `inclinationAngle::T`: Inclination angle of the object (optional, 0.0 as default).
    - `rotation::T`: Rotation of the object (optional, 0.0 as default).

# Details

`object_table` can be of any format that implement the `Tables.jl` interface, *e.g.* an array of `NamedTuple`s, a `DataFrame`...

# Example

```julia
using Meshes
using Tables
using PlantGeom

scene_dimensions = (Meshes.Point(0.0, 0.0, 0.0), Meshes.Point(100.0, 100.0, 100.0))
positions = [Meshes.Point(50.0, 50.0, 50.0), Meshes.Point(60.0, 60.0, 60.0), Meshes.Point(70.0, 70.0, 70.0)]
object_table = [
    (sceneID=1, plantID=p, filePath="opf/plant_\$p.opf", pos=positions[p], functional_group="plant", rotation=0.1) for p in 1:3
]

write_ops("scene.ops", scene_dimensions, object_table)
"""
function write_ops(file, scene_dimensions, object_table)
    dims = join([
            Unitful.ustrip.(u"m", Meshes.to(scene_dimensions[1]))...,
            Unitful.ustrip.(u"m", Meshes.to(scene_dimensions[2]))...
        ][1:end-1], " ")
    ops_lines = vcat("# T xOrigin yOrigin zOrigin xSize ySize flat", string("T ", dims..., " flat"))

    # Sort object_table by functional_group:
    sorted_table = sort(Tables.rows(object_table), by=row -> row.functional_group)
    current_group = ""
    for row in sorted_table
        if row.functional_group != current_group
            current_group = row.functional_group
            ops_lines = vcat(ops_lines,
                "#[Archimed] $current_group",
                "#sceneId plantId plantFileName x y z scale inclinationAzimut inclinationAngle stemTwist")
        end
        x, y, z = Unitful.ustrip.(u"m", Meshes.to(row.pos))
        plant_scale = haskey(row, :scale) ? row.scale : 1.0
        plant_rotation = haskey(row, :rotation) ? row.rotation : 0.0
        plant_inclinationAzimut = haskey(row, :inclinationAzimut) ? row.inclinationAzimut : 0.0
        plant_inclinationAngle = haskey(row, :inclinationAngle) ? row.inclinationAngle : 0.0

        ops_lines = vcat(ops_lines,
            join([row.sceneID, row.plantID, row.filePath, x, y, z, plant_scale, plant_inclinationAzimut, plant_inclinationAngle, plant_rotation], "\t"))
    end

    open(file, "w") do io
        for line in ops_lines
            println(io, line)
        end
    end
end