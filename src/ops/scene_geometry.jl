"""
    SceneNodeData

Generic per-node geometry summary used by [`SceneGeometry`](@ref).

The data is intentionally geometry-only. Semantic attributes such as `group`,
`type`, cultivar, treatment, or material class stay on the source MTG nodes.
Downstream models can read and compile those attributes during their own
preparation step.
"""
struct SceneNodeData{T}
    area::Union{Nothing,T}
    barycenter::Union{Nothing,NTuple{3,T}}
    source_topology_id::Union{Nothing,Int}
end

"""
    SceneGeometry

Prepared generic scene representation.

It stores the source MTG, a merged mesh, a face-to-node map, optional per-node
geometry summaries, the source path, and the scene XY domain.
"""
mutable struct SceneGeometry{MTG,Mesh,T}
    mtg::MTG
    merged_mesh::Mesh
    face2node::Vector{Int}
    nodes::Dict{Int,SceneNodeData{T}}
    source_path::String
    scene_xy_bounds::Union{Nothing,NTuple{4,T}}
end

mutable struct SceneBuilder
    mtg
    domain::Union{Nothing,NTuple{4,Float64}}
    source_path::String
    compute_area::Bool
    compute_barycenter::Bool
    source_topology_id::Bool
end

scene_node(scene::SceneGeometry, node_id::Integer) = get(scene.nodes, Int(node_id), nothing)
scene_node_ids(scene::SceneGeometry) = sort!(collect(keys(scene.nodes)))
node_areas(scene::SceneGeometry) = Dict(nid => node.area for (nid, node) in scene.nodes)
node_barycenters(scene::SceneGeometry) = Dict(nid => node.barycenter for (nid, node) in scene.nodes)

function _coerce_scene_domain(domain)
    domain === nothing && return nothing
    length(domain) == 4 || error("Scene domain must be a 4-tuple `(xmin, ymin, xmax, ymax)`.")
    vals = ntuple(i -> Float64(domain[i]), 4)
    vals[3] > vals[1] || error("Scene domain must satisfy xmax > xmin.")
    vals[4] > vals[2] || error("Scene domain must satisfy ymax > ymin.")
    return vals
end

function _set_scene_dimensions!(mtg, bounds::NTuple{4,Float64})
    xmin, ymin, xmax, ymax = bounds
    mtg[:scene_dimensions] = (
        GeometryBasics.Point3f(Float32(xmin), Float32(ymin), 0.0f0),
        GeometryBasics.Point3f(Float32(xmax), Float32(ymax), 0.0f0),
    )
    return mtg
end

function _scene_root(domain::Union{Nothing,NTuple{4,Float64}})
    root = MultiScaleTreeGraph.Node(
        MultiScaleTreeGraph.NodeMTG(:/, :Scene, 1, 0),
        Dict{Symbol,Any}(),
    )
    domain === nothing || _set_scene_dimensions!(root, domain)
    return root
end

@inline function _is_scene_geometry_node(node)
    has_geometry(node) || return false
    !haskey(node, :scene_dimensions)
end

function _scene_xy_bounds_from_mtg(mtg)
    haskey(mtg, :scene_dimensions) || return nothing
    dims = mtg[:scene_dimensions]
    dims === nothing && return nothing
    if dims isa AbstractString
        matches = collect(eachmatch(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", dims))
        length(matches) >= 5 || return nothing
        values = parse.(Float64, getfield.(matches, :match))
        return (
            min(values[1], values[4]),
            min(values[2], values[5]),
            max(values[1], values[4]),
            max(values[2], values[5]),
        )
    end
    p0 = dims[1]
    p1 = dims[2]
    return (
        min(Float64(p0[1]), Float64(p1[1])),
        min(Float64(p0[2]), Float64(p1[2])),
        max(Float64(p0[1]), Float64(p1[1])),
        max(Float64(p0[2]), Float64(p1[2])),
    )
end

function _scene_triangle_area3d(p1, p2, p3)
    v1 = StaticArrays.SVector{3,Float64}(p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3])
    v2 = StaticArrays.SVector{3,Float64}(p3[1] - p1[1], p3[2] - p1[2], p3[3] - p1[3])
    0.5 * norm(cross(v1, v2))
end

function _source_topology_id(node)
    haskey(node, :source_topology_id) || return nothing
    v = node[:source_topology_id]
    (v === nothing || ismissing(v)) && return nothing
    try
        id = Int(v)
        id > 0 && return id
    catch
    end
    return nothing
end

function prepare_scene(
    mtg;
    source_path::AbstractString="interactive.scene",
    domain=nothing,
    scene_xy_bounds=nothing,
    relabel_ids::Bool=false,
    compute_area::Bool=true,
    compute_barycenter::Bool=true,
    source_topology_id::Bool=true,
)
    relabel_ids && _relabel_node_ids!(mtg, Ref(1))
    bounds = domain === nothing ? scene_xy_bounds : domain
    bounds = bounds === nothing ? _scene_xy_bounds_from_mtg(mtg) : _coerce_scene_domain(bounds)
    bounds === nothing || _set_scene_dimensions!(mtg, bounds)

    merged_mesh, face2node = build_merged_mesh_with_map(mtg; filter_fun=_is_scene_geometry_node)
    node_ids = sort!(unique(face2node))
    nodes = Dict{Int,SceneNodeData{Float64}}()

    node_area = Dict{Int,Float64}()
    bary_acc = Dict{Int,NTuple{3,Float64}}()
    if compute_area || compute_barycenter
        verts = GeometryBasics.decompose(GeometryBasics.Point3, merged_mesh)
        faces = GeometryBasics.decompose(Face3, merged_mesh)
        for (i, f) in enumerate(faces)
            nid = face2node[i]
            p1 = verts[f[1]]
            p2 = verts[f[2]]
            p3 = verts[f[3]]
            area = _scene_triangle_area3d(p1, p2, p3)
            (compute_area || compute_barycenter) && (node_area[nid] = get(node_area, nid, 0.0) + area)
            if compute_barycenter
                cx = (p1[1] + p2[1] + p3[1]) / 3.0
                cy = (p1[2] + p2[2] + p3[2]) / 3.0
                cz = (p1[3] + p2[3] + p3[3]) / 3.0
                sx, sy, sz = get(bary_acc, nid, (0.0, 0.0, 0.0))
                bary_acc[nid] = (sx + area * cx, sy + area * cy, sz + area * cz)
            end
        end
    end

    for nid in node_ids
        area = compute_area ? get(node_area, nid, 0.0) : nothing
        barycenter =
            if compute_barycenter
                denom = compute_area ? get(node_area, nid, 0.0) : begin
                    # Recompute the denominator from accumulated weights only when area is disabled.
                    # The fallback keeps the API simple; users needing barycenters usually keep area on.
                    get(node_area, nid, 0.0)
                end
                if denom > 0
                    sx, sy, sz = get(bary_acc, nid, (0.0, 0.0, 0.0))
                    (sx / denom, sy / denom, sz / denom)
                else
                    (NaN, NaN, NaN)
                end
            else
                nothing
            end
        sid =
            if source_topology_id
                node = MultiScaleTreeGraph.get_node(mtg, nid)
                node === nothing ? nid : something(_source_topology_id(node), nid)
            else
                nothing
            end
        nodes[nid] = SceneNodeData(area, barycenter, sid)
    end

    return SceneGeometry(mtg, merged_mesh, face2node, nodes, String(source_path), bounds)
end

function _refresh_scene!(scene::SceneGeometry; compute_area::Bool=true, compute_barycenter::Bool=true, source_topology_id::Bool=true)
    scene.mtg === nothing && error("Scene refresh requires an MTG-backed scene.")
    bump_scene_version!(scene.mtg)
    refreshed = prepare_scene(
        scene.mtg;
        source_path=scene.source_path,
        scene_xy_bounds=scene.scene_xy_bounds,
        relabel_ids=false,
        compute_area=compute_area,
        compute_barycenter=compute_barycenter,
        source_topology_id=source_topology_id,
    )
    scene.merged_mesh = refreshed.merged_mesh
    scene.face2node = refreshed.face2node
    scene.nodes = refreshed.nodes
    scene.scene_xy_bounds = refreshed.scene_xy_bounds
    return scene
end

function _mesh_object_mtg(mesh; type::AbstractString, name::AbstractString="object")
    root = MultiScaleTreeGraph.Node(
        MultiScaleTreeGraph.NodeMTG(:/, :Object, 1, 1),
        Dict{Symbol,Any}(),
    )
    MultiScaleTreeGraph.Node(
        2,
        root,
        MultiScaleTreeGraph.NodeMTG(:+, Symbol(type), 2, 2),
        Dict{Symbol,Any}(
            :geometry => Geometry(ref_mesh=RefMesh(String(name), mesh)),
            :type => String(type),
        ),
    )
    return root
end

function _read_scene_object(path::AbstractString; type::AbstractString="object")
    ext = lowercase(splitext(path)[2])
    ext == ".opf" && return read_opf(path, attr_type=Dict, attribute_types=Dict("pos" => Float64))
    ext == ".gwa" && return read_gwa(path)
    error("add_object! accepts `.opf` and `.gwa` paths directly. For mesh files such as `.obj` or `.ply`, load them with MeshIO/FileIO first, then pass the mesh to add_object!. Use read_ops for `.ops` scenes.")
end

function _set_node_attrs!(node; attrs...)
    for (k, v) in attrs
        node[Symbol(k)] = v
    end
    return node
end

function _annotate_object_root!(root; group::AbstractString, id::Integer, file_path::AbstractString="", attrs...)
    root[:group] = String(group)
    root[:functional_group] = String(group)
    root[:id] = Int(id)
    root[:object_id] = Int(id)
    root[:plantID] = Int(id)
    isempty(file_path) || (root[:filePath] = String(file_path))
    _set_node_attrs!(root; attrs...)
    return root
end

function _transform_object!(mtg, transformation)
    MultiScaleTreeGraph.traverse!(mtg, filter_fun=has_geometry) do node
        transform_mesh!(node, transformation)
        return true
    end
    return mtg
end

function _rotation_is_zero(rotate)
    if rotate isa NamedTuple
        return all(axis -> Float64(getproperty(rotate, axis)) == 0.0, propertynames(rotate))
    end
    length(rotate) == 3 || error("`rotate` must be a 3-tuple or a named tuple.")
    x, y, z = ntuple(i -> Float64(rotate[i]), 3)
    return x == 0.0 && y == 0.0 && z == 0.0
end

function _placement_transform(;
    at=(0.0, 0.0, 0.0),
    scale=1.0,
    rotate=(0.0, 0.0, 0.0),
    deg::Bool=false,
    rotation=nothing,
    inclination_azimut=0.0,
    inclination_angle=0.0,
    transform=nothing,
)
    if rotation !== nothing || inclination_azimut != 0.0 || inclination_angle != 0.0
        _rotation_is_zero(rotate) || error("Use either `rotate=` or OPS-style `rotation=`/`inclination_*=` placement, not both.")
        scale isa Real || error("OPS-style placement with `rotation=`/`inclination_*=` requires scalar `scale`.")
        ops = scene_object_transformation(
            ;
            at=at,
            scale=Float64(scale),
            rotation=rotation === nothing ? 0.0 : (deg ? deg2rad(Float64(rotation)) : Float64(rotation)),
            inclination_azimut=deg ? deg2rad(Float64(inclination_azimut)) : Float64(inclination_azimut),
            inclination_angle=deg ? deg2rad(Float64(inclination_angle)) : Float64(inclination_angle),
        )
        return transform === nothing ? ops : ops ∘ transform
    end
    p = pose(; scale=scale, rotate=rotate, at=at, deg=deg)
    return transform === nothing ? p : p ∘ transform
end

function add_object!(
    builder::SceneBuilder,
    object;
    group::AbstractString,
    id::Integer,
    type::AbstractString="object",
    at=(0.0, 0.0, 0.0),
    scale=1.0,
    rotate=(0.0, 0.0, 0.0),
    deg::Bool=false,
    rotation=nothing,
    inclination_azimut=0.0,
    inclination_angle=0.0,
    transform=nothing,
    file_path::AbstractString="",
    kwargs...,
)
    obj = object isa GeometryBasics.AbstractMesh ? _mesh_object_mtg(object; type=type) : deepcopy(object)
    _annotate_object_root!(obj; group=group, id=id, file_path=file_path, kwargs...)
    _transform_object!(
        obj,
        _placement_transform(
            ;
            at=at,
            scale=scale,
            rotate=rotate,
            deg=deg,
            rotation=rotation,
            inclination_azimut=inclination_azimut,
            inclination_angle=inclination_angle,
            transform=transform,
        ),
    )
    MultiScaleTreeGraph.addchild!(builder.mtg, obj)
    return builder
end

function add_object!(builder::SceneBuilder, path::AbstractString; type::AbstractString="object", kwargs...)
    add_object!(builder, _read_scene_object(path; type=type); type=type, file_path=path, kwargs...)
end

add_plant!(builder::SceneBuilder, plant; group::AbstractString, id::Integer, kwargs...) =
    add_object!(builder, plant; group=group, id=id, kwargs...)

add_plant!(builder::SceneBuilder, path::AbstractString; group::AbstractString, id::Integer, kwargs...) =
    add_object!(builder, path; group=group, id=id, kwargs...)

function _add_ground_nodes!(
    mtg,
    bounds::NTuple{4,Float64};
    z::Real=0.0,
    nx::Int=9,
    ny::Int=9,
    group::AbstractString="pavement",
    type::AbstractString="Cobblestone",
    id::Integer=-1,
    kwargs...,
)
    xmin, ymin, xmax, ymax = bounds
    x_edges = collect(range(Float64(xmin), Float64(xmax), length=nx + 1))
    y_edges = collect(range(Float64(ymin), Float64(ymax), length=ny + 1))
    root_scale = MultiScaleTreeGraph.scale(mtg)
    mtg_type = typeof(MultiScaleTreeGraph.node_mtg(mtg))
    next_id = MultiScaleTreeGraph.max_id(mtg) + 1

    for ix in 1:nx, iy in 1:ny
        x0 = x_edges[ix]
        x1 = x_edges[ix+1]
        y0 = y_edges[iy]
        y1 = y_edges[iy+1]
        points = GeometryBasics.Point3f[
            GeometryBasics.Point3f(Float32(x0), Float32(y0), Float32(z)),
            GeometryBasics.Point3f(Float32(x1), Float32(y0), Float32(z)),
            GeometryBasics.Point3f(Float32(x1), Float32(y1), Float32(z)),
            GeometryBasics.Point3f(Float32(x0), Float32(y1), Float32(z)),
        ]
        faces = Face3[Face3(1, 2, 3), Face3(1, 3, 4)]
        mesh = GeometryBasics.Mesh(points, faces)
        nid = next_id
        next_id += 1
        attrs = Dict{Symbol,Any}(
            :geometry => Geometry(ref_mesh=RefMesh("$(group)_$(nid)", mesh)),
            :group => String(group),
            :functional_group => String(group),
            :type => String(type),
            :id => Int(id),
            :object_id => Int(id),
            :source_topology_id => nid,
        )
        for (k, v) in kwargs
            attrs[Symbol(k)] = v
        end
        MultiScaleTreeGraph.Node(
            nid,
            mtg,
            mtg_type(:+, Symbol(type), nid, root_scale + 1),
            attrs,
        )
    end

    haskey(mtg, :geometry) && (mtg[:geometry] = nothing)
    return mtg
end

function add_ground!(
    scene::SceneGeometry;
    z::Real=0.0,
    nx::Int=9,
    ny::Int=9,
    xy_bounds=nothing,
    group::AbstractString="pavement",
    type::AbstractString="Cobblestone",
    id::Integer=-1,
    kwargs...,
)
    scene.mtg === nothing && error("add_ground! requires an MTG-backed scene.")
    bounds = xy_bounds === nothing ? scene.scene_xy_bounds : _coerce_scene_domain(xy_bounds)
    bounds === nothing && error("Ground bounds are undefined. Pass `xy_bounds=` or use a scene with a domain.")
    _add_ground_nodes!(scene.mtg, bounds; z=z, nx=nx, ny=ny, group=group, type=type, id=id, kwargs...)

    scene.scene_xy_bounds = bounds
    return _refresh_scene!(scene)
end

function add_ground!(
    builder::SceneBuilder;
    z::Real=0.0,
    nx::Int=9,
    ny::Int=9,
    xy_bounds=nothing,
    group::AbstractString="pavement",
    type::AbstractString="Cobblestone",
    id::Integer=-1,
    kwargs...,
)
    bounds = xy_bounds === nothing ? builder.domain : _coerce_scene_domain(xy_bounds)
    bounds === nothing && error("Ground bounds are undefined. Pass `domain=` to `make_scene` or `xy_bounds=` to `add_ground!`.")
    _add_ground_nodes!(builder.mtg, bounds; z=z, nx=nx, ny=ny, group=group, type=type, id=id, kwargs...)
    builder.domain = bounds
    return builder
end

function make_scene(
    f::Function;
    domain,
    source_path::AbstractString="interactive.scene",
    compute_area::Bool=true,
    compute_barycenter::Bool=true,
    source_topology_id::Bool=true,
)
    bounds = _coerce_scene_domain(domain)
    builder = SceneBuilder(_scene_root(bounds), bounds, String(source_path), compute_area, compute_barycenter, source_topology_id)
    f(builder)
    return prepare_scene(
        builder.mtg;
        source_path=builder.source_path,
        scene_xy_bounds=builder.domain,
        relabel_ids=true,
        compute_area=compute_area,
        compute_barycenter=compute_barycenter,
        source_topology_id=source_topology_id,
    )
end

function make_scene(;
    domain,
    source_path::AbstractString="interactive.scene",
    compute_area::Bool=true,
    compute_barycenter::Bool=true,
    source_topology_id::Bool=true,
)
    make_scene(identity; domain=domain, source_path=source_path, compute_area=compute_area, compute_barycenter=compute_barycenter, source_topology_id=source_topology_id)
end
