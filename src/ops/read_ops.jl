"""
    read_ops(file; attr_type=Dict{String,Any}, mtg_type=MutableNodeMTG, kwargs...)

Reads an OPS file and returns the content as a `MultiScaleTreeGraph`.

Additional keyword arguments are forwarded to [`read_ops_file`](@ref), e.g.
`relaxed=true` and `assume_scale_column=false` for legacy OPS rows where the
scale column is missing.
"""
function read_ops(file; attr_type=Dict, mtg_type=MutableNodeMTG, kwargs...)
    scene_dimensions, object_table = read_ops_file(file; kwargs...)

    scene = Node(mtg_type("/", "Scene", 1, 0), MultiScaleTreeGraph.init_empty_attr(attr_type))
    scene.scene_dimensions = scene_dimensions

    node_max_id = Ref(0)

    opfs = Node[]
    opf_orig_position = Dict{String,Int}()
    for row in Tables.rows(object_table)
        opf_file = row.filePath
        if haskey(opf_orig_position, opf_file)
            opf = deepcopy(opfs[opf_orig_position[opf_file]])
            traverse!(opf) do node
                setfield!(node, :id, node_max_id[])
                node_max_id[] += 1
            end
            push!(opfs, opf)
        else
            object_path = joinpath(dirname(file), opf_file)
            ext = lowercase(splitext(opf_file)[2])
            opf = if ext == ".opf"
                read_opf(object_path, attr_type=attr_type, mtg_type=mtg_type, read_id=false, max_id=node_max_id)
            elseif ext == ".gwa"
                read_gwa(object_path, attr_type=attr_type, mtg_type=mtg_type, read_id=false, max_id=node_max_id)
            else
                error("Unsupported OPS object extension: $ext in $file")
            end
            haskey(node_attributes(opf), :ref_meshes) && delete!(node_attributes(opf), :ref_meshes)
            push!(opfs, opf)
            opf_orig_position[opf_file] = length(opfs)
        end
    end

    for (i, row) in enumerate(Tables.rows(object_table))
        opf = opfs[i]

        scene_transformation = IdentityTransformation()

        if row.rotation != 0.0
            scene_transformation = compose_lr(scene_transformation, LinearMap(RotZ(row.rotation)))
        end

        if row.scale != 1.0
            scene_transformation = compose_lr(scene_transformation, LinearMap(Diagonal(SVector(row.scale, row.scale, row.scale))))
        end

        if row.inclinationAzimut != 0.0
            @warn "InclinationAzimut is not yet implemented."
        end

        if row.inclinationAngle != 0.0
            @warn "InclinationAngle is not yet implemented."
        end

        if row.pos != point3(0.0, 0.0, 0.0)
            scene_transformation = compose_lr(scene_transformation, Translation(row.pos[1], row.pos[2], row.pos[3]))
        end

        traverse!(opf, filter_fun=node -> !isnothing(node.geometry)) do node
            scene_transformation != IdentityTransformation() && transform_mesh!(node, scene_transformation)
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

    p_0 = scene_dimensions[1]
    p_max = scene_dimensions[2]

    p = [
        point3(p_0),
        point3(p_max[1], p_0[2], p_0[3]),
        point3(p_max),
        point3(p_0[1], p_max[2], p_0[3])
    ]
    c = [face3(1, 2, 3), face3(3, 4, 1)]
    scene_quadrangle = _mesh(p, c)

    scene_refmesh = RefMesh("Scene", scene_quadrangle, RGBA(159 / 255, 182 / 255, 205 / 255, 0.1))
    scene.geometry = Geometry(ref_mesh=scene_refmesh)

    return scene
end
