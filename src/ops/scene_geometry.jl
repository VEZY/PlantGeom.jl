"""
    SceneNodeData

Generic per-node geometry summary used by [`SceneGeometry`](@ref).

The data is intentionally geometry-only. Semantic attributes such as `group`,
`type`, cultivar, treatment, or material class stay on the source MTG nodes.
Downstream models can read and compile those attributes during their own
preparation step.

Fields:

- `area`: total triangle area associated with one MTG node, or `nothing` when
  area computation was disabled.
- `barycenter`: area-weighted 3D barycenter `(x, y, z)`, or `nothing` when
  barycenter computation was disabled.
- `source_topology_id`: original topology id copied from the source object when
  available. If no explicit source id exists, [`prepare_scene`](@ref) falls back
  to the current node id when `source_topology_id=true`.
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

Fields:

- `mtg`: scene MTG root. Its children are placed object roots or generated
  ground cells.
- `merged_mesh`: one mesh built from all geometry-bearing nodes in the scene.
- `face2node`: vector mapping each face in `merged_mesh` to the MTG node id that
  produced it.
- `nodes`: dictionary from MTG node id to [`SceneNodeData`](@ref).
- `source_path`: descriptive path or label for provenance.
- `scene_xy_bounds`: scene domain as `(xmin, ymin, xmax, ymax)`, or `nothing`
  when no domain is known.
"""
mutable struct SceneGeometry{MTG,Mesh,T}
    mtg::MTG
    merged_mesh::Mesh
    face2node::Vector{Int}
    nodes::Dict{Int,SceneNodeData{T}}
    source_path::String
    scene_xy_bounds::Union{Nothing,NTuple{4,T}}
end

"""
    SceneBuilder

Mutable builder passed to [`make_scene`](@ref) callback blocks.

Users normally do not construct `SceneBuilder` directly. Instead, use:

```julia
scene = make_scene(domain=(0.0, 0.0, 10.0, 5.0)) do builder
    add_plant!(builder, plant; group="plants", id=1)
    add_ground!(builder)
end
```

Fields:

- `mtg`: scene root being assembled.
- `domain`: scene XY domain as `(xmin, ymin, xmax, ymax)`.
- `source_path`: provenance label forwarded to [`SceneGeometry`](@ref).
- `compute_area`: whether prepared node summaries should include surface area.
- `compute_barycenter`: whether summaries should include area-weighted
  barycenters.
- `source_topology_id`: whether summaries should preserve source topology ids.
"""
mutable struct SceneBuilder
    mtg
    domain::Union{Nothing,NTuple{4,Float64}}
    source_path::String
    compute_area::Bool
    compute_barycenter::Bool
    source_topology_id::Bool
    next_node_id::Int
end

SceneBuilder(
    mtg,
    domain::Union{Nothing,NTuple{4,Float64}},
    source_path::String,
    compute_area::Bool,
    compute_barycenter::Bool,
    source_topology_id::Bool,
) = SceneBuilder(
    mtg,
    domain,
    source_path,
    compute_area,
    compute_barycenter,
    source_topology_id,
    MultiScaleTreeGraph.max_id(mtg) + 1,
)

"""
    scene_node(scene::SceneGeometry, node_id)

Return the [`SceneNodeData`](@ref) summary for `node_id`, or `nothing` if that
node has no prepared geometry summary.
"""
scene_node(scene::SceneGeometry, node_id::Integer) = get(scene.nodes, Int(node_id), nothing)

"""
    scene_node_ids(scene::SceneGeometry)

Return the sorted MTG node ids present in the prepared scene summaries.

These are the ids used in `scene.face2node`, [`scene_node`](@ref),
[`node_areas`](@ref), and [`node_barycenters`](@ref).
"""
scene_node_ids(scene::SceneGeometry) = sort!(collect(keys(scene.nodes)))

"""
    node_areas(scene::SceneGeometry)

Return a dictionary mapping each prepared MTG node id to its surface area.

Values are `nothing` when the scene was prepared with `compute_area=false`.
"""
node_areas(scene::SceneGeometry) = Dict(nid => node.area for (nid, node) in scene.nodes)

"""
    node_barycenters(scene::SceneGeometry)

Return a dictionary mapping each prepared MTG node id to its area-weighted
barycenter `(x, y, z)`.

Values are `nothing` when the scene was prepared with
`compute_barycenter=false`. Degenerate zero-area nodes receive `(NaN, NaN, NaN)`
when barycenter computation is enabled.
"""
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

function _scene_root(
    domain::Union{Nothing,NTuple{4,Float64}};
    mtg_type=MultiScaleTreeGraph.NodeMTG,
)
    root = MultiScaleTreeGraph.Node(
        mtg_type(:/, :Scene, 1, 0),
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

"""
    prepare_scene(mtg; source_path="interactive.scene", domain=nothing,
                  scene_xy_bounds=nothing, relabel_ids=false,
                  compute_area=true, compute_barycenter=true,
                  source_topology_id=true)

Prepare an MTG scene root for geometry-level downstream work.

`prepare_scene` expects an MTG whose geometry-bearing descendants already live
in scene coordinates. It merges all geometry nodes into one mesh and builds a
face-to-node map so every face in the merged mesh can be traced back to the MTG
node that produced it.

Keyword arguments:

- `source_path`: provenance label stored on the returned [`SceneGeometry`](@ref).
- `domain`: explicit scene XY domain `(xmin, ymin, xmax, ymax)`. When provided,
  it takes precedence over `scene_xy_bounds` and over `mtg[:scene_dimensions]`.
- `scene_xy_bounds`: fallback scene XY domain `(xmin, ymin, xmax, ymax)`.
- `relabel_ids`: when `true`, relabel MTG node ids before merging. This is
  useful after assembling independent object roots that may have overlapping
  ids.
- `compute_area`: compute total triangle area per MTG node.
- `compute_barycenter`: compute area-weighted barycenter per MTG node.
- `source_topology_id`: preserve original topology ids in node summaries when
  nodes carry a `:source_topology_id` attribute.

The function mutates `mtg` when `relabel_ids=true` or when a domain is written
back as `mtg[:scene_dimensions]`. It returns a [`SceneGeometry`](@ref).

Use [`make_scene`](@ref) for new scene construction; use `prepare_scene`
directly when you already have a scene MTG.
"""
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

function _read_scene_object(
    path::AbstractString;
    type::AbstractString="object",
    mtg_type=MultiScaleTreeGraph.MutableNodeMTG,
)
    ext = lowercase(splitext(path)[2])
    ext == ".opf" && return read_opf(
        path,
        attr_type=Dict,
        mtg_type=mtg_type,
        attribute_types=Dict("pos" => Float64),
    )
    ext == ".gwa" && return read_gwa(path; mtg_type=mtg_type)
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

function _ops_rotation_metadata(rotate, deg::Bool)
    rotation = 0.0
    for (axis, angle) in _manual_rotation_sequence(rotate)
        angle == 0.0 && continue
        axis === :z || return nothing
        rotation = _manual_angle_rad(angle, deg)
    end
    return rotation
end

function _store_ops_placement_metadata!(
    root,
    scene_transformation;
    at,
    scale,
    rotate,
    deg::Bool,
    rotation,
    inclination_azimut,
    inclination_angle,
    transform,
)
    transform === nothing || return root
    scale isa Real || return root

    rotation_val = if rotation === nothing
        _ops_rotation_metadata(rotate, deg)
    else
        _manual_angle_rad(rotation, deg)
    end
    rotation_val === nothing && return root

    root[:pos] = _scene_point3(at)
    root[:scale] = Float64(scale)
    root[:rotation] = rotation_val
    root[:inclinationAzimut] = deg ? deg2rad(Float64(inclination_azimut)) : Float64(inclination_azimut)
    root[:inclinationAngle] = deg ? deg2rad(Float64(inclination_angle)) : Float64(inclination_angle)
    root[:scene_transformation] = scene_transformation
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
    return all(pair -> last(pair) == 0.0, _manual_rotation_sequence(rotate))
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

"""
    add_object!(builder::SceneBuilder, object; group, id, type="object",
                at=(0, 0, 0), scale=1.0, rotate=(0, 0, 0), deg=false,
                rotation=nothing, inclination_azimut=0.0,
                inclination_angle=0.0, transform=nothing,
                file_path="", kwargs...)
    add_object!(builder::SceneBuilder, path::AbstractString; type="object", kwargs...)

Add an object to a scene being assembled with [`make_scene`](@ref).

`object` can be:

- an MTG root containing geometry, such as an object read from `.opf` or `.gwa`
- a `GeometryBasics.AbstractMesh`, which is wrapped in a minimal object MTG

The path overload accepts `.opf` and `.gwa` files and reads them before adding
the object. It uses the same MTG encoding type as `builder.mtg`, so it works with
both `NodeMTG` and `MutableNodeMTG` scenes. For mesh formats such as `.obj` or
`.ply`, load the mesh yourself with a suitable IO package and pass the mesh
object directly.

Required metadata:

- `group`: semantic group name. Stored as both `:group` and
  `:functional_group`.
- `id`: object id. Stored as `:id`, `:object_id`, and `:plantID`.

Placement options:

- `at=(x, y, z)`: final translation.
- `scale=s` or `scale=(sx, sy, sz)`: uniform or anisotropic scaling for the
  simple transform path.
- `rotate=(x=..., y=..., z=...)` or `rotate=(rx, ry, rz)`: simple local-axis
  rotations used by [`pose`](@ref).
- `deg=true`: interpret `rotate`, `rotation`, `inclination_azimut`, and
  `inclination_angle` as degrees.
- `rotation`, `inclination_azimut`, `inclination_angle`: OPS-style scalar
  placement. These cannot be mixed with a nonzero `rotate=` value.
- `transform`: extra `CoordinateTransformations.Transformation` composed after
  the placement transform.

`add_object!` deep-copies MTG inputs before mutating them, annotates the object
root with placement metadata, applies the placement transform to all geometry
nodes, attaches the object under `builder.mtg`, and returns `builder`.

Extra keyword arguments are written as attributes on the copied object root.
All objects added to one builder must use the same MTG encoding type as the
scene root, for example `NodeMTG` with `NodeMTG`, or `MutableNodeMTG` with
`MutableNodeMTG`.
"""
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
    placement = _placement_transform(
        ;
        at=at,
        scale=scale,
        rotate=rotate,
        deg=deg,
        rotation=rotation,
        inclination_azimut=inclination_azimut,
        inclination_angle=inclination_angle,
        transform=transform,
    )
    _transform_object!(
        obj,
        placement,
    )
    _store_ops_placement_metadata!(
        obj,
        placement;
        at=at,
        scale=scale,
        rotate=rotate,
        deg=deg,
        rotation=rotation,
        inclination_azimut=inclination_azimut,
        inclination_angle=inclination_angle,
        transform=transform,
    )
    next_node_id = Ref(builder.next_node_id)
    _relabel_node_ids!(obj, next_node_id)
    builder.next_node_id = next_node_id[]
    MultiScaleTreeGraph.addchild!(builder.mtg, obj)
    return builder
end

function add_object!(builder::SceneBuilder, path::AbstractString; type::AbstractString="object", kwargs...)
    mtg_type = typeof(MultiScaleTreeGraph.node_mtg(builder.mtg))
    add_object!(
        builder,
        _read_scene_object(path; type=type, mtg_type=mtg_type);
        type=type,
        file_path=path,
        kwargs...,
    )
end

"""
    add_plant!(builder::SceneBuilder, plant; group, id, kwargs...)
    add_plant!(builder::SceneBuilder, path::AbstractString; group, id, kwargs...)

Add a plant object to a scene being assembled with [`make_scene`](@ref).

This is a semantic alias for [`add_object!`](@ref) with the same placement and
metadata keywords. Use it for plant MTGs or plant files when the scene contains
both biological plants and non-plant objects.

Required keywords:

- `group`: functional group or treatment label, stored on the object root.
- `id`: plant id, stored as `:id`, `:object_id`, and `:plantID`.

Common placement keywords include `at`, `scale`, `rotate`, `deg`, `rotation`,
`inclination_azimut`, `inclination_angle`, and `transform`; see
[`add_object!`](@ref) for the full behavior.

The input MTG is deep-copied before placement, so the same loaded plant can be
added more than once with different ids or positions.
"""
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

"""
    add_ground!(builder::SceneBuilder; z=0.0, nx=9, ny=9, xy_bounds=nothing,
                group="pavement", type="Cobblestone", id=-1, kwargs...)
    add_ground!(scene::SceneGeometry; z=0.0, nx=9, ny=9, xy_bounds=nothing,
                group="pavement", type="Cobblestone", id=-1, kwargs...)

Add a rectangular ground mesh to a scene.

The ground is represented as a regular `nx` by `ny` grid of quadrilateral cells,
triangulated as two faces per cell. The grid is inserted directly in the scene
MTG as geometry-bearing child nodes. Each cell receives a `Geometry` with a
single `RefMesh`, plus the following attributes:

- `group` and `functional_group`: set from `group`
- `type`: set from `type`
- `id` and `object_id`: set from `id`
- `source_topology_id`: set to the generated node id
- any extra keyword arguments passed through `kwargs...`

By default, the ground extent comes from the scene domain:

- for a `SceneBuilder`, from `make_scene(domain=...)`
- for a `SceneGeometry`, from `scene.scene_xy_bounds`

Pass `xy_bounds=(xmin, ymin, xmax, ymax)` to override that extent. The `z`
keyword sets the elevation of all ground vertices.

When called inside a `make_scene do builder ... end` block, this method mutates
the builder and returns it. When called on an already prepared `SceneGeometry`,
it mutates the backing MTG, refreshes the merged scene geometry, and returns the
updated `SceneGeometry`.

# Examples

```julia
scene = make_scene(domain=(0.0, 0.0, 8.0, 4.0)) do builder
    add_ground!(builder; nx=8, ny=4, group="ground", type="Ground")
end
```

```julia
add_ground!(
    scene;
    xy_bounds=(-1.0, -1.0, 1.0, 1.0),
    z=-0.02,
    nx=2,
    ny=2,
    material=:soil,
)
```
"""
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
    builder.next_node_id = max(builder.next_node_id, MultiScaleTreeGraph.max_id(builder.mtg) + 1)
    return builder
end

"""
    make_scene(f; domain, mtg_type=NodeMTG, source_path="interactive.scene", ...)
    make_scene(; domain, mtg_type=NodeMTG, source_path="interactive.scene", ...)

Create a scene root, run the builder callback `f`, and return a prepared
[`SceneGeometry`](@ref).

This is the recommended high-level scene assembly API. The callback receives a
[`SceneBuilder`](@ref); call [`add_plant!`](@ref), [`add_object!`](@ref), and
[`add_ground!`](@ref) inside the callback to populate the scene.

Keyword arguments:

- `domain`: required scene XY domain `(xmin, ymin, xmax, ymax)`. It is stored as
  scene dimensions and used as the default extent for [`add_ground!`](@ref).
- `mtg_type`: MTG encoding type used for the scene root. Keep it consistent
  with the objects added to the scene, e.g. `NodeMTG` with `NodeMTG` objects or
  `MutableNodeMTG` with `MutableNodeMTG` objects.
- `source_path`: provenance label stored in the returned [`SceneGeometry`](@ref).
- `compute_area`: compute per-node surface areas.
- `compute_barycenter`: compute per-node area-weighted barycenters.
- `source_topology_id`: preserve source topology ids when available.

Objects added through the builder are relabelled as they are inserted, so
independent object roots with overlapping ids can safely share one scene without
rebuilding the full attribute store after each insertion. After the callback
returns, `make_scene` calls [`prepare_scene`](@ref). The returned value is a
[`SceneGeometry`](@ref); use
`scene.mtg` when a function expects the scene MTG, for example
`plantviz(scene.mtg)` or `write_ops(file, scene.mtg)`.

# Examples

```julia
scene = make_scene(domain=(0.0, 0.0, 8.0, 4.0)) do builder
    add_plant!(builder, plant; group="plants", id=1, at=(1.0, 1.0, 0.0))
    add_ground!(builder; nx=8, ny=4)
end
```

```julia
scene = make_scene(
    domain=(0.0, 0.0, 8.0, 4.0);
    mtg_type=MutableNodeMTG,
) do builder
    add_plant!(builder, mutable_plant; group="plants", id=1)
end
```
"""
function make_scene(
    f::Function;
    domain,
    mtg_type=MultiScaleTreeGraph.NodeMTG,
    source_path::AbstractString="interactive.scene",
    compute_area::Bool=true,
    compute_barycenter::Bool=true,
    source_topology_id::Bool=true,
)
    bounds = _coerce_scene_domain(domain)
    root = _scene_root(bounds; mtg_type=mtg_type)
    builder = SceneBuilder(
        root,
        bounds,
        String(source_path),
        compute_area,
        compute_barycenter,
        source_topology_id,
        MultiScaleTreeGraph.max_id(root) + 1,
    )
    f(builder)
    return prepare_scene(
        builder.mtg;
        source_path=builder.source_path,
        scene_xy_bounds=builder.domain,
        relabel_ids=false,
        compute_area=compute_area,
        compute_barycenter=compute_barycenter,
        source_topology_id=source_topology_id,
    )
end

function make_scene(;
    domain,
    mtg_type=MultiScaleTreeGraph.NodeMTG,
    source_path::AbstractString="interactive.scene",
    compute_area::Bool=true,
    compute_barycenter::Bool=true,
    source_topology_id::Bool=true,
)
    make_scene(
        identity;
        domain=domain,
        mtg_type=mtg_type,
        source_path=source_path,
        compute_area=compute_area,
        compute_barycenter=compute_barycenter,
        source_topology_id=source_topology_id,
    )
end
