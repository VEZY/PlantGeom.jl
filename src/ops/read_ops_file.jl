"""
    read_ops_file(file)

Read the content of an `.ops` file and return a tuple with the scene dimensions and the object table.

# Arguments

- `file::String`: Path of the `.ops` file to read.

# Returns

The scene dimensions and the object table as a tuple. The scene dimensions are a tuple
of two `Point3` with the origin point and opposite point of the scene.
The object table is an array of `NamedTuple` with the following fields:
- `sceneID::Int`: Scene ID.
- `plantID::Int`: Plant ID.
- `filePath::String`: Path to the `.opf` or `.gwa` file.
- `pos::Point3`: Position of the object.
- `scale::Float64`: Scale of the object.
- `inclinationAzimut::Float64`: Inclination azimut of the object.
- `inclinationAngle::Float64`: Inclination angle of the object.
- `rotation::Float64`: Rotation of the object.
- `functional_group::String`: Functional group of the object.
"""
function read_ops_file(file)
    lines = readlines(file)

    scene_dim_line = findfirst(x -> occursin(r"^T ([+-]?\d+(\.\d+)?)(\s+[+-]?\d+(\.\d+)?){4}\s+flat", x), lines)
    if scene_dim_line === nothing
        error("Scene dimensions not found in file $file")
    end
    scene_dim_values = lines[scene_dim_line] |> x -> replace(x, "T" => "") |> strip |> split
    length(scene_dim_values) == 6 || error("Scene dimensions incomplete in file $file, expected `xOrigin yOrigin zOrigin xSize ySize flat`, got: $scene_dim_values")
    scene_dim_values = parse.(Float64, scene_dim_values[1:5])
    scene_dimensions = (point3(scene_dim_values[1:3]), point3(scene_dim_values[4], scene_dim_values[5], scene_dim_values[3]))

    object_table = NamedTuple[]
    functional_group = ""
    for (i, line) in enumerate(lines[scene_dim_line+1:end])
        if occursin("#[Archimed]", line)
            functional_group = replace(line, "#[Archimed] " => "") |> strip
            continue
        end

        if occursin(r"^\d+\t\d+\t.*\.(opf|gwa)\t([+-]?\d+(\.\d+)?\t){6}[+-]?\d+(\.\d+)?$", line)
            if functional_group == ""
                error("Functional group not found for line $(i+scene_dim_line+1): $line in file $file")
            end
            sceneID, plantID, filePath, x, y, z, scale, inclinationAzimut, inclinationAngle, rotation = split(line, "\t")
            pos = point3(parse.(Float64, (x, y, z)))
            sceneID = parse(Int, sceneID)
            plantID = parse(Int, plantID)
            scale = parse(Float64, scale)
            inclinationAzimut = parse(Float64, inclinationAzimut)
            inclinationAngle = parse(Float64, inclinationAngle)
            rotation = parse(Float64, rotation)

            push!(object_table, (; sceneID, plantID, filePath, pos, scale, inclinationAzimut, inclinationAngle, rotation, functional_group))
        end
    end

    return (; scene_dimensions, object_table)
end
