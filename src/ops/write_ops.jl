"""
    write_ops(file, scene_dimensions, object_table)

Write a scene file (`.ops`), with the given dimensions and object table.

# Arguments

- `file::String`: Path of the `.ops` file to write.
- `scene_dimensions::Tuple{Point3,Point3}`: Dimensions of the scene.
- `object_table`: Table with the objects to write in the `.ops` file.
"""
function write_ops(file, scene_dimensions, object_table)
    dims = join([
            scene_dimensions[1][1], scene_dimensions[1][2], scene_dimensions[1][3],
            scene_dimensions[2][1], scene_dimensions[2][2]
        ], " ")
    ops_lines = vcat("# T xOrigin yOrigin zOrigin xSize ySize flat", string("T ", dims..., " flat"))

    sorted_table = sort(Tables.rows(object_table), by=row -> row.functional_group)
    current_group = ""
    for row in sorted_table
        if row.functional_group != current_group
            current_group = row.functional_group
            ops_lines = vcat(ops_lines,
                "#[Archimed] $current_group",
                "#sceneId plantId plantFileName x y z scale inclinationAzimut inclinationAngle stemTwist")
        end

        x, y, z = row.pos
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
