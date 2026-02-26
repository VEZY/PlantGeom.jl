@inline _ops_write_ext(path::AbstractString) = lowercase(splitext(path)[2])

@inline function _ops_row_value(row, key::Symbol, default)
    hasproperty(row, key) && return getproperty(row, key)
    haskey(row, key) && return row[key]
    return default
end

@inline function _ops_scene_value(node::MultiScaleTreeGraph.Node, key::Symbol, default)
    hasproperty(node, key) ? getproperty(node, key) : default
end

@inline function _ops_object_ext(node::MultiScaleTreeGraph.Node, file_path_hint::AbstractString)
    ext = _ops_write_ext(file_path_hint)
    ext in (".opf", ".gwa") && return ext
    symbol(node) == :GWA && return ".gwa"
    return ".opf"
end

function _ops_sanitize_relpath(path::AbstractString)
    raw = replace(path, '\\' => '/')
    tokens = filter(!isempty, split(raw, '/'))
    isempty(tokens) && return ""
    rel = joinpath(tokens...)
    isabspath(rel) && return basename(rel)
    startswith(normpath(rel), "..") && return basename(rel)
    return rel
end

function _ops_default_relpath(node::MultiScaleTreeGraph.Node, row_idx::Int, ext::AbstractString, objects_subdir::AbstractString)
    scene_id = _ops_scene_value(node, :sceneID, 1)
    plant_id = _ops_scene_value(node, :plantID, row_idx)
    fname = "scene$(scene_id)_plant$(plant_id)_$(row_idx)$(ext)"
    return joinpath(objects_subdir, fname)
end

function _ops_object_relpath(
    node::MultiScaleTreeGraph.Node,
    row_idx::Int,
    ext::AbstractString;
    objects_subdir::AbstractString,
    preserve_file_paths::Bool
)
    if preserve_file_paths && hasproperty(node, :filePath)
        rel = _ops_sanitize_relpath(string(node.filePath))
        if !isempty(rel)
            rel_ext = _ops_write_ext(rel)
            return rel_ext == "" ? rel * ext : rel
        end
    end
    return _ops_default_relpath(node, row_idx, ext, objects_subdir)
end

function _strip_scene_metadata!(object_root::MultiScaleTreeGraph.Node)
    attrs = node_attributes(object_root)
    for key in (
        :scene_transformation,
        :sceneID,
        :functional_group,
        :plantID,
        :filePath,
        :pos,
        :scale,
        :inclinationAzimut,
        :inclinationAngle,
        :rotation
    )
        pop!(attrs, key, nothing)
    end
    return object_root
end

function _unapply_scene_transformation!(object_root::MultiScaleTreeGraph.Node, scene_transformation)
    scene_inv = inv(scene_transformation)
    traverse!(object_root, filter_fun=node -> has_geometry(node)) do node
        transform_mesh!(node, scene_inv)
    end
    return object_root
end

function _scene_object_for_write(node::MultiScaleTreeGraph.Node)
    object_root = deepcopy(node)
    reparent!(object_root, nothing)
    _strip_scene_metadata!(object_root)

    if hasproperty(node, :scene_transformation)
        _unapply_scene_transformation!(object_root, node.scene_transformation)
    end

    return object_root
end

function _write_ops_object(file::AbstractString, object_root::MultiScaleTreeGraph.Node, ext::AbstractString)
    ext == ".opf" && return write_opf(file, object_root)
    ext == ".gwa" && return write_gwa(file, object_root)
    error("Unsupported OPS object extension: $ext for $file")
end

function _scene_to_ops_rows(
    ops_file::AbstractString,
    scene::MultiScaleTreeGraph.Node;
    write_objects::Bool,
    objects_subdir::AbstractString,
    preserve_file_paths::Bool
)
    ops_dir = dirname(ops_file)
    rows = NamedTuple[]

    for (i, object_root) in enumerate(children(scene))
        scene_id = _ops_scene_value(object_root, :sceneID, 1)
        plant_id = _ops_scene_value(object_root, :plantID, i)
        pos = _ops_scene_value(object_root, :pos, point3(0.0, 0.0, 0.0))
        scale = _ops_scene_value(object_root, :scale, 1.0)
        inclination_azimut = _ops_scene_value(object_root, :inclinationAzimut, 0.0)
        inclination_angle = _ops_scene_value(object_root, :inclinationAngle, 0.0)
        rotation = _ops_scene_value(object_root, :rotation, 0.0)
        functional_group = string(_ops_scene_value(object_root, :functional_group, ""))
        file_path_hint = string(_ops_scene_value(object_root, :filePath, ""))
        ext = _ops_object_ext(object_root, file_path_hint)

        rel_path = _ops_object_relpath(
            object_root,
            i,
            ext;
            objects_subdir=objects_subdir,
            preserve_file_paths=preserve_file_paths
        )

        if write_objects
            object_file = joinpath(ops_dir, rel_path)
            mkpath(dirname(object_file))
            object_export = _scene_object_for_write(object_root)
            _write_ops_object(object_file, object_export, ext)
        end

        push!(
            rows,
            (
                sceneID=scene_id,
                plantID=plant_id,
                filePath=rel_path,
                pos=pos,
                scale=scale,
                inclinationAzimut=inclination_azimut,
                inclinationAngle=inclination_angle,
                rotation=rotation,
                functional_group=functional_group
            )
        )
    end

    return rows
end

"""
    write_ops_file(file, scene_dimensions, object_table)

Write only the scene table (`.ops`) from scene dimensions and object rows.
This does not write referenced `.opf` / `.gwa` object files.
"""
function write_ops_file(file, scene_dimensions, object_table)
    lines = String[]
    if !isnothing(scene_dimensions)
        dims = join([
                scene_dimensions[1][1], scene_dimensions[1][2], scene_dimensions[1][3],
                scene_dimensions[2][1], scene_dimensions[2][2]
            ], " ")
        push!(lines, "# T xOrigin yOrigin zOrigin xSize ySize flat")
        push!(lines, string("T ", dims, " flat"))
    end

    current_group = nothing
    for row in Tables.rows(object_table)
        row_group = string(_ops_row_value(row, :functional_group, ""))
        if current_group != row_group
            current_group = row_group
            push!(lines, "#[Archimed] $row_group")
            push!(lines, "#sceneId plantId plantFileName x y z scale inclinationAzimut inclinationAngle stemTwist")
        end

        pos = _ops_row_value(row, :pos, point3(0.0, 0.0, 0.0))
        x, y, z = pos
        scene_id = _ops_row_value(row, :sceneID, 1)
        plant_id = _ops_row_value(row, :plantID, 1)
        file_path = string(_ops_row_value(row, :filePath, "object.opf"))
        plant_scale = _ops_row_value(row, :scale, 1.0)
        plant_rotation = _ops_row_value(row, :rotation, 0.0)
        plant_inclination_azimut = _ops_row_value(row, :inclinationAzimut, 0.0)
        plant_inclination_angle = _ops_row_value(row, :inclinationAngle, 0.0)

        push!(
            lines,
            join(
                [
                    scene_id,
                    plant_id,
                    file_path,
                    x,
                    y,
                    z,
                    plant_scale,
                    plant_inclination_azimut,
                    plant_inclination_angle,
                    plant_rotation
                ],
                "\t"
            )
        )
    end

    mkpath(dirname(file))
    open(file, "w") do io
        for line in lines
            println(io, line)
        end
    end

    return file
end

"""
    write_ops(file, scene_dimensions, object_table)

Write only the scene table (`.ops`) from explicit scene dimensions and object rows.
Alias to [`write_ops_file`](@ref).
"""
write_ops(file, scene_dimensions, object_table) = write_ops_file(file, scene_dimensions, object_table)

"""
    write_ops(file, scene; write_objects=true, objects_subdir="objects", preserve_file_paths=false)

Write a scene MTG to an `.ops` file. By default this writes one object file per
scene child (`.opf` / `.gwa`) and emits an OPS row pointing to each object.

- `write_objects=true`: also write object files next to the `.ops` file.
- `objects_subdir="objects"`: target subdirectory for generated object files when
  `preserve_file_paths=false`.
- `preserve_file_paths=false`: when `true`, reuse each child `filePath` (sanitized
  to remain relative) for emitted object paths.
"""
function write_ops(
    file,
    scene::MultiScaleTreeGraph.Node;
    write_objects::Bool=true,
    objects_subdir::AbstractString="objects",
    preserve_file_paths::Bool=false
)
    root = isroot(scene) ? scene : get_root(scene)
    scene_dimensions = hasproperty(root, :scene_dimensions) ? root.scene_dimensions : nothing
    object_rows = _scene_to_ops_rows(
        file,
        root;
        write_objects=write_objects,
        objects_subdir=objects_subdir,
        preserve_file_paths=preserve_file_paths
    )
    return write_ops_file(file, scene_dimensions, object_rows)
end
