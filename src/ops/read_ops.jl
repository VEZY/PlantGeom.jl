"""
    read_ops(file; attr_type=Dict{String,Any}, mtg_type=MutableNodeMTG,
             attribute_types=Dict(), materialize_scene_boundary=false, kwargs...)

Reads an OPS file and returns the content as a `MultiScaleTreeGraph`.
Per-object OPS transforms (`rotation`, `scale`, `inclinationAzimut`/`inclinationAngle`,
and `pos`) are applied to geometry during loading.
Geometry nodes preserve their original object-local topology ids in
`:source_topology_id` (from OPF/GWA files), while MTG indices remain unique at
scene scope.

Additional keyword arguments are forwarded to [`read_ops_file`](@ref), e.g.
`relaxed=true` and `assume_scale_column=false` for legacy OPS rows where the
scale column is missing.

`attr_type` is kept for backward compatibility and ignored with
MultiScaleTreeGraph >= v0.15 (columnar attributes backend).

`attribute_types` is forwarded to [`read_opf`](@ref) and can be used to
override OPF attribute types by name (CSV-like typing override).

`materialize_scene_boundary=false` keeps the `:Scene` root as a geometry-free
container. The OPS terrain line is retained in `scene_dimensions` and can be
materialized later with [`add_ground!`](@ref). Set the keyword to `true` only
for the historical translucent plotting quadrangle; such a root-boundary mesh
is a visualization artifact and must be removed before [`prepare_scene`](@ref).
"""
function read_ops(
    file;
    attr_type=Dict,
    mtg_type=MutableNodeMTG,
    attribute_types=Dict(),
    materialize_scene_boundary::Bool=false,
    kwargs...,
)
    scene_dimensions, object_table = read_ops_file(file; kwargs...)

    scene = Node(mtg_type(:/, :Scene, 1, 0), MultiScaleTreeGraph.init_empty_attr())
    scene.scene_dimensions = scene_dimensions

    # MTG columnar attributes are indexed by positive node ids; reserve 1 for scene root.
    node_max_id = Ref(2)
    next_node_id = Ref(2)

    opfs = Node[]
    opf_orig_position = Dict{String,Int}()
    for row in Tables.rows(object_table)
        opf_file = row.filePath
        if haskey(opf_orig_position, opf_file)
            opf = deepcopy(opfs[opf_orig_position[opf_file]])
            _relabel_node_ids!(opf, next_node_id)
            push!(opfs, opf)
        else
            object_path = joinpath(dirname(file), opf_file)
            ext = lowercase(splitext(opf_file)[2])
            opf = if ext == ".opf"
                read_opf(
                    object_path,
                    attr_type=attr_type,
                    mtg_type=mtg_type,
                    read_id=false,
                    max_id=node_max_id,
                    attribute_types=attribute_types
                )
            elseif ext == ".gwa"
                read_gwa(object_path, attr_type=attr_type, mtg_type=mtg_type, read_id=false, max_id=node_max_id)
            else
                error("Unsupported OPS object extension: $ext in $file")
            end
            _relabel_node_ids!(opf, next_node_id)
            haskey(opf, :ref_meshes) && pop!(opf, :ref_meshes)
            push!(opfs, opf)
            opf_orig_position[opf_file] = length(opfs)
        end
    end

    for (i, row) in enumerate(Tables.rows(object_table))
        opf = opfs[i]

        scene_transformation = scene_object_transformation(
            ;
            at=row.pos,
            scale=row.scale,
            rotation=row.rotation,
            inclination_azimut=row.inclinationAzimut,
            inclination_angle=row.inclinationAngle,
        )

        traverse!(opf, filter_fun=has_geometry) do node
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

    # Historical PlantGeom releases attached a translucent plot-boundary
    # quadrangle directly to the :Scene root. That makes the root both a
    # container and a geometric component, which is incompatible with durable
    # source ownership and canonical scene assembly. Keep it as an explicit
    # opt-in visualization artifact; scientific ground geometry belongs on a
    # child created with `add_ground!`.
    if materialize_scene_boundary && !isnothing(scene_dimensions)
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
    end

    # OPS scenes are assembled by attaching pre-built OPF/GWA subtrees.
    # Rebind the final tree to a single columnar store so columnar queries
    # (e.g. descendants from the scene root) use coherent bucket metadata.
    MultiScaleTreeGraph.columnarize!(scene)

    return scene
end
