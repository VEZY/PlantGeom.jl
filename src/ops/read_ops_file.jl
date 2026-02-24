@inline _ops_file_ext(path::AbstractString) = lowercase(splitext(path)[2])

function _ops_default_scale(path::AbstractString, opf_scale::Float64, gwa_scale::Float64)
    ext = _ops_file_ext(path)
    ext == ".gwa" && return gwa_scale
    ext == ".opf" && return opf_scale
    return opf_scale
end

"""
    read_ops_file(file; relaxed=false, assume_scale_column=true, opf_scale=1.0, gwa_scale=1.0, require_functional_group=false, default_functional_group="")

Read the content of an `.ops` file and return a tuple with the scene dimensions and the object table.

# Arguments

- `file::String`: Path of the `.ops` file to read.
- `relaxed::Bool=false`: If `true`, parse rows using whitespace separators and accept extra
  trailing columns in object rows.
- `assume_scale_column::Bool=true`: If `false`, interpret object rows as legacy
  `x y z inclinationAzimut inclinationAngle rotation [ignored...]` (missing scale) and inject
  scale values using `opf_scale`/`gwa_scale`.
- `opf_scale::Float64=1.0`: Default object scale applied to `.opf` rows when
  `assume_scale_column=false`.
- `gwa_scale::Float64=1.0`: Default object scale applied to `.gwa` rows when
  `assume_scale_column=false`.
- `require_functional_group::Bool=false`: If `true`, throw when parsing an object row before
  any `#[Archimed] ...` section header.
- `default_functional_group::AbstractString=""`: Value assigned to `functional_group` when
  no `#[Archimed] ...` header is active.

# Returns

The scene dimensions and the object table as a tuple. The scene dimensions are a tuple
of two `GeometryBasics.Point{3,Float64}` with the origin point and opposite point of the scene.
The object table is an array of `NamedTuple` with the following fields:
- `sceneID::Int`: Scene ID.
- `plantID::Int`: Plant ID.
- `filePath::String`: Path to the `.opf` or `.gwa` file.
- `pos::GeometryBasics.Point{3,Float64}`: Position of the object.
- `scale::Float64`: Scale of the object.
- `inclinationAzimut::Float64`: Inclination azimut of the object.
- `inclinationAngle::Float64`: Inclination angle of the object.
- `rotation::Float64`: Rotation of the object.
- `functional_group::String`: Functional group of the object.
"""
function read_ops_file(
    file;
    relaxed=false,
    assume_scale_column=true,
    opf_scale=1.0,
    gwa_scale=1.0,
    require_functional_group=false,
    default_functional_group="",
)
    lines = readlines(file)

    scene_dim_line = if relaxed
        findfirst(x -> startswith(strip(replace(x, '\r' => "")), "T "), lines)
    else
        findfirst(x -> occursin(r"^T ([+-]?\d+(\.\d+)?)(\s+[+-]?\d+(\.\d+)?){4}\s+flat", x), lines)
    end
    scene_dim_line === nothing && error("Scene dimensions not found in file $file")

    scene_dim_values = lines[scene_dim_line] |> x -> replace(x, "T" => "") |> strip |> split
    length(scene_dim_values) == 6 || error("Scene dimensions incomplete in file $file, expected `xOrigin yOrigin zOrigin xSize ySize flat`, got: $scene_dim_values")
    scene_dim_values = parse.(Float64, scene_dim_values[1:5])
    scene_dimensions = (point3(scene_dim_values[1:3]), point3(scene_dim_values[4], scene_dim_values[5], scene_dim_values[3]))

    object_table = NamedTuple[]
    functional_group = string(default_functional_group)
    for (i, line) in enumerate(lines[scene_dim_line+1:end])
        if occursin("#[Archimed]", line)
            functional_group = replace(line, r"^.*#\[Archimed\]\s*" => "") |> strip
            continue
        end

        if !relaxed
            if occursin(r"^\d+\t\d+\t.*\.(opf|gwa)\t([+-]?\d+(\.\d+)?\t){6}[+-]?\d+(\.\d+)?$", line)
                if require_functional_group && functional_group == ""
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
            continue
        end

        st = strip(replace(line, '\r' => ""))
        (isempty(st) || startswith(st, "#")) && continue

        toks = split(st)
        length(toks) < 9 && continue

        filePath = toks[3]
        _ops_file_ext(filePath) in (".opf", ".gwa") || continue

        if require_functional_group && functional_group == ""
            error("Functional group not found for line $(i+scene_dim_line+1): $line in file $file")
        end

        sceneID = parse(Int, toks[1])
        plantID = parse(Int, toks[2])
        x = parse(Float64, toks[4])
        y = parse(Float64, toks[5])
        z = parse(Float64, toks[6])

        if assume_scale_column
            length(toks) >= 10 || error("Incomplete OPS object row at line $(i+scene_dim_line+1) in file $file")
            scale = parse(Float64, toks[7])
            inclinationAzimut = parse(Float64, toks[8])
            inclinationAngle = parse(Float64, toks[9])
            rotation = parse(Float64, toks[10])
        else
            scale = _ops_default_scale(filePath, Float64(opf_scale), Float64(gwa_scale))
            inclinationAzimut = parse(Float64, toks[7])
            inclinationAngle = parse(Float64, toks[8])
            rotation = parse(Float64, toks[9])
        end

        pos = point3(x, y, z)
        push!(object_table, (; sceneID, plantID, filePath, pos, scale, inclinationAzimut, inclinationAngle, rotation, functional_group))
    end

    return (; scene_dimensions, object_table)
end
