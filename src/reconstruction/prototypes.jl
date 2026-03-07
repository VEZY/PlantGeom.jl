abstract type AbstractMeshPrototype end
abstract type AbstractParametricPrototype <: AbstractMeshPrototype end

const _PROTOTYPE_ATTR_ALIASES = (
    :GeometryPrototype,
    :geometry_prototype,
    :prototype,
)

const _PROTOTYPE_OVERRIDES_ALIASES = (
    :GeometryPrototypeOverrides,
    :geometry_prototype_overrides,
    :prototype_overrides,
)

@inline _proto_as_symbol(x::Symbol) = x
@inline _proto_as_symbol(x::AbstractString) = Symbol(x)

@inline _proto_axis_indices(::Val{:x}) = (1, 2, 3)
@inline _proto_axis_indices(::Val{:y}) = (2, 1, 3)
@inline _proto_axis_indices(::Val{:z}) = (3, 1, 2)

@inline _proto_axis_indices(length_axis::Symbol) =
    length_axis == :x ? _proto_axis_indices(Val(:x)) :
    length_axis == :y ? _proto_axis_indices(Val(:y)) :
    length_axis == :z ? _proto_axis_indices(Val(:z)) :
    error("Invalid length axis '$length_axis'. Expected :x, :y or :z.")

@inline _proto_span(lo::Float64, hi::Float64) = hi - lo

@inline _proto_nt(x::NamedTuple) = x
@inline _proto_nt(::Nothing) = NamedTuple()
@inline _proto_nt(x::Base.Pairs) = NamedTuple(x)
function _proto_nt(x::AbstractDict)
    d = Dict{Symbol,Any}()
    for (k, v) in pairs(x)
        d[_proto_as_symbol(k)] = v
    end
    (; d...)
end

function _proto_nt(x)
    error("Unsupported overrides container $(typeof(x)). Expected NamedTuple, Dict, Pairs, or nothing.")
end

function _normalize_aliases_tuple(v)
    if v === nothing
        return ()
    elseif v isa Symbol || v isa AbstractString
        return (_proto_as_symbol(v),)
    elseif v isa Tuple || v isa AbstractVector
        return Tuple(_proto_as_symbol(x) for x in v)
    end
    error("Invalid alias container $(typeof(v)). Expected Symbol, String, Tuple, or Vector.")
end

function _normalize_attr_aliases_nt(attr_aliases)
    raw = _proto_nt(attr_aliases)
    d = Dict{Symbol,Tuple}()
    for (k, v) in pairs(raw)
        d[_proto_as_symbol(k)] = _normalize_aliases_tuple(v)
    end
    ordered = sort!(collect(keys(d)); by=String)
    return (; (k => d[k] for k in ordered)...)
end

function _normalize_metadata_nt(parameter_metadata)
    raw = _proto_nt(parameter_metadata)
    d = Dict{Symbol,Any}()
    for (k, v) in pairs(raw)
        d[_proto_as_symbol(k)] = v
    end
    ordered = sort!(collect(keys(d)); by=String)
    return (; (k => d[k] for k in ordered)...)
end

function _compute_mesh_bbox(mesh)
    verts = _vertices(mesh)
    isempty(verts) && return (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)

    xmin = Inf
    xmax = -Inf
    ymin = Inf
    ymax = -Inf
    zmin = Inf
    zmax = -Inf

    @inbounds for p in verts
        x = Float64(p[1])
        y = Float64(p[2])
        z = Float64(p[3])
        x < xmin && (xmin = x)
        x > xmax && (xmax = x)
        y < ymin && (ymin = y)
        y > ymax && (ymax = y)
        z < zmin && (zmin = z)
        z > zmax && (zmax = z)
    end

    (xmin, xmax, ymin, ymax, zmin, zmax)
end

function _normalize_ref_mesh_to_unit(ref_mesh::RefMesh; length_axis::Symbol=:x, warn::Bool=true)
    bounds = _compute_mesh_bbox(ref_mesh.mesh)
    (xmin, xmax, ymin, ymax, zmin, zmax) = bounds
    idx_l, idx_t1, idx_t2 = _proto_axis_indices(length_axis)

    mins = (xmin, ymin, zmin)
    maxs = (xmax, ymax, zmax)

    lmin = mins[idx_l]
    lmax = maxs[idx_l]
    t1min = mins[idx_t1]
    t1max = maxs[idx_t1]
    t2min = mins[idx_t2]
    t2max = maxs[idx_t2]

    lspan = _proto_span(lmin, lmax)
    t1span = _proto_span(t1min, t1max)
    t2span = _proto_span(t2min, t2max)
    t1mid = 0.5 * (t1min + t1max)
    t2mid = 0.5 * (t2min + t2max)

    tol = 1e-8
    already_normalized = abs(lmin) <= tol &&
                         abs(lmax - 1.0) <= tol &&
                         abs(t1mid) <= tol &&
                         abs(t2mid) <= tol &&
                         abs(t1span - 1.0) <= tol &&
                         abs(t2span - 1.0) <= tol

    already_normalized && return ref_mesh, true

    lden = lspan > 1e-12 ? lspan : 1.0
    t1den = t1span > 1e-12 ? t1span : 1.0
    t2den = t2span > 1e-12 ? t2span : 1.0

    verts = _vertices(ref_mesh.mesh)
    normalized_vertices = Vector{_Point3}(undef, length(verts))
    @inbounds for i in eachindex(verts)
        p = verts[i]
        coords = (Float64(p[1]), Float64(p[2]), Float64(p[3]))
        l = (coords[idx_l] - lmin) / lden
        t1 = (coords[idx_t1] - t1mid) / t1den
        t2 = (coords[idx_t2] - t2mid) / t2den
        out = [coords[1], coords[2], coords[3]]
        out[idx_l] = l
        out[idx_t1] = t1
        out[idx_t2] = t2
        normalized_vertices[i] = point3(out[1], out[2], out[3])
    end

    normalized_mesh = _mesh(normalized_vertices, _faces(ref_mesh.mesh))
    normalized_ref_mesh = RefMesh(
        ref_mesh.name,
        normalized_mesh,
        ref_mesh.normals,
        ref_mesh.texture_coords,
        ref_mesh.material,
        ref_mesh.taper,
    )

    if warn
        @warn "Normalized prototype mesh to unit convention." ref_mesh = ref_mesh.name length_axis = length_axis
    end

    return normalized_ref_mesh, false
end

struct RefMeshPrototype{R<:RefMesh} <: AbstractMeshPrototype
    ref_mesh::R
    normalized::Bool
end

function RefMeshPrototype(
    ref_mesh::RefMesh;
    normalize::Bool=true,
    warn::Bool=true,
    length_axis::Symbol=:x,
)
    if normalize
        normalized_ref_mesh, _ = _normalize_ref_mesh_to_unit(
            ref_mesh;
            length_axis=length_axis,
            warn=warn,
        )
        return RefMeshPrototype(normalized_ref_mesh, true)
    end
    RefMeshPrototype(ref_mesh, false)
end

struct RawMeshPrototype{R<:RefMesh} <: AbstractMeshPrototype
    ref_mesh::R
end

struct PointMapPrototype{R<:RefMesh,D<:NamedTuple,A<:NamedTuple,FI,FP,PM<:NamedTuple} <: AbstractParametricPrototype
    ref_mesh::R
    defaults::D
    attr_aliases::A
    intrinsic_shape::FI
    physical_deformation::FP
    parameter_metadata::PM
end

function PointMapPrototype(
    ref_mesh::RefMesh;
    defaults=NamedTuple(),
    attr_aliases=NamedTuple(),
    intrinsic_shape=nothing,
    physical_deformation=nothing,
    parameter_metadata=NamedTuple(),
    normalize::Bool=true,
    warn::Bool=true,
    length_axis::Symbol=:x,
)
    ref_proto = RefMeshPrototype(ref_mesh; normalize=normalize, warn=warn, length_axis=length_axis)
    PointMapPrototype(
        ref_proto.ref_mesh,
        _proto_nt(defaults),
        _normalize_attr_aliases_nt(attr_aliases),
        intrinsic_shape,
        physical_deformation,
        _normalize_metadata_nt(parameter_metadata),
    )
end

struct ExtrusionPrototype{D<:NamedTuple,A<:NamedTuple,BL,FI,FP,PM<:NamedTuple} <: AbstractParametricPrototype
    defaults::D
    attr_aliases::A
    build_local::BL
    intrinsic_shape::FI
    physical_deformation::FP
    parameter_metadata::PM
end

function ExtrusionPrototype(
    build_local;
    defaults=NamedTuple(),
    attr_aliases=NamedTuple(),
    intrinsic_shape=nothing,
    physical_deformation=nothing,
    parameter_metadata=NamedTuple(),
)
    ExtrusionPrototype(
        _proto_nt(defaults),
        _normalize_attr_aliases_nt(attr_aliases),
        build_local,
        intrinsic_shape,
        physical_deformation,
        _normalize_metadata_nt(parameter_metadata),
    )
end

@inline _prototype_defaults(::AbstractMeshPrototype) = NamedTuple()
@inline _prototype_defaults(proto::AbstractParametricPrototype) = proto.defaults

@inline _prototype_aliases(::AbstractMeshPrototype) = NamedTuple()
@inline _prototype_aliases(proto::AbstractParametricPrototype) = proto.attr_aliases

@inline _prototype_metadata(::AbstractMeshPrototype) = NamedTuple()
@inline _prototype_metadata(proto::AbstractParametricPrototype) = proto.parameter_metadata

function _prototype_parameter_order(proto::AbstractMeshPrototype)
    defaults = _prototype_defaults(proto)
    aliases = _prototype_aliases(proto)
    metadata = _prototype_metadata(proto)
    names = Symbol[]
    append!(names, propertynames(defaults))
    for k in propertynames(aliases)
        k in names || push!(names, k)
    end
    for k in propertynames(metadata)
        k in names || push!(names, k)
    end
    return Tuple(names)
end

function _prototype_allowed_keys(proto::AbstractMeshPrototype)
    Set(_prototype_parameter_order(proto))
end

function _prototype_try_attr(node, name::Symbol)
    try
        if haskey(node, name)
            return node[name], true
        end
    catch
    end

    if node isa AbstractDict
        s = String(name)
        if haskey(node, s)
            return node[s], true
        end
    end

    try
        if hasproperty(node, name)
            return getproperty(node, name), true
        end
    catch
    end

    nothing, false
end

function _prototype_node_overrides(node)
    for key in _PROTOTYPE_OVERRIDES_ALIASES
        value, found = _prototype_try_attr(node, key)
        found || continue
        value === nothing && return NamedTuple()
        return _proto_nt(value)
    end
    NamedTuple()
end

function _prototype_call_overrides(prototype_overrides, node)
    if prototype_overrides === nothing
        return NamedTuple()
    elseif prototype_overrides isa Function
        value = prototype_overrides(node)
        value === nothing && return NamedTuple()
        return _proto_nt(value)
    end
    _proto_nt(prototype_overrides)
end

function _validate_override_keys(proto::AbstractMeshPrototype, params::NamedTuple, label::String)
    allowed = _prototype_allowed_keys(proto)
    bad = Symbol[]
    for k in keys(params)
        k in allowed || push!(bad, k)
    end
    isempty(bad) && return
    allowed_sorted = sort!(collect(allowed); by=String)
    error("$label contains unknown parameter(s): $(join(string.(bad), ", ")). Allowed parameters: $(join(string.(allowed_sorted), ", ")).")
end

function available_parameters(proto::AbstractMeshPrototype)
    defaults = _prototype_defaults(proto)
    aliases = _prototype_aliases(proto)
    metadata = _prototype_metadata(proto)
    out = NamedTuple[]
    for name in _prototype_parameter_order(proto)
        default = hasproperty(defaults, name) ? getproperty(defaults, name) : nothing
        alias_vals = hasproperty(aliases, name) ? getproperty(aliases, name) : ()
        meta = hasproperty(metadata, name) ? getproperty(metadata, name) : nothing
        push!(out, (
            name=name,
            default=default,
            type=default === nothing ? Any : typeof(default),
            aliases=alias_vals,
            metadata=meta,
        ))
    end
    out
end

"""
    effective_parameters(node, prototype; overrides=NamedTuple())

Resolve prototype parameters for a node with precedence:
`overrides` > node prototype overrides > node attribute aliases > prototype defaults.
"""
function effective_parameters(node, proto::AbstractMeshPrototype; overrides=NamedTuple())
    defaults = _prototype_defaults(proto)
    aliases = _prototype_aliases(proto)
    node_overrides = _prototype_node_overrides(node)
    call_overrides = _proto_nt(overrides)

    _validate_override_keys(proto, node_overrides, "Node prototype overrides")
    _validate_override_keys(proto, call_overrides, "Call prototype overrides")

    d = Dict{Symbol,Any}()
    for k in propertynames(defaults)
        d[k] = getproperty(defaults, k)
    end

    for k in propertynames(aliases)
        alias_names = getproperty(aliases, k)
        for alias_name in alias_names
            raw, found = _prototype_try_attr(node, alias_name)
            if found && raw !== nothing && raw !== missing
                d[k] = raw
                break
            end
        end
    end

    for (k, v) in pairs(node_overrides)
        d[k] = v
    end
    for (k, v) in pairs(call_overrides)
        d[k] = v
    end

    names = _prototype_parameter_order(proto)
    (; (k => get(d, k, nothing) for k in names)...)
end

@inline _as_prototype(x::AbstractMeshPrototype) = x
@inline _as_prototype(x::RefMesh) = RefMeshPrototype(x; normalize=true, warn=false)

function _as_prototype(x)
    error("Unsupported prototype value $(typeof(x)). Expected `AbstractMeshPrototype` or `RefMesh`.")
end

function _prepare_prototype_library(prototypes::AbstractDict)
    out = Dict{Any,AbstractMeshPrototype}()
    for (k, v) in pairs(prototypes)
        out[k] = _as_prototype(v)
    end
    out
end

function _resolve_prototype_from_key(prototypes::AbstractDict, key)
    haskey(prototypes, key) && return prototypes[key]
    if key isa Symbol
        s = String(key)
        haskey(prototypes, s) && return prototypes[s]
    elseif key isa AbstractString
        s = Symbol(key)
        haskey(prototypes, s) && return prototypes[s]
    end
    nothing
end

function _node_prototype_token(node)
    for key in _PROTOTYPE_ATTR_ALIASES
        value, found = _prototype_try_attr(node, key)
        found || continue
        value === nothing && continue
        return value
    end
    nothing
end

function _resolve_prototype(node, prototypes::AbstractDict, prototype_selector::Union{Nothing,Function}=nothing)
    if prototype_selector !== nothing
        selected = prototype_selector(node)
        if selected !== nothing
            if selected isa AbstractMeshPrototype || selected isa RefMesh
                return _as_prototype(selected)
            end
            resolved = _resolve_prototype_from_key(prototypes, selected)
            resolved === nothing && error("`prototype_selector` returned '$selected', which is not in `prototypes`.")
            return resolved
        end
    end

    token = _node_prototype_token(node)
    if token !== nothing
        if token isa AbstractMeshPrototype || token isa RefMesh
            return _as_prototype(token)
        end
        resolved = _resolve_prototype_from_key(prototypes, token)
        resolved === nothing && error("Node prototype token '$token' is not present in `prototypes`.")
        return resolved
    end

    name = symbol(node)
    resolved = _resolve_prototype_from_key(prototypes, name)
    resolved !== nothing && return resolved

    resolved = _resolve_prototype_from_key(prototypes, String(name))
    resolved
end
