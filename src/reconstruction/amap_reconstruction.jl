"""
    AmapReconstructionOptions

Configuration for AMAP-style reconstruction stages used by
`set_geometry_from_attributes!`, `reconstruct_geometry_from_attributes!`, and
`rebuild_geometry!`.

This type controls how PlantGeom interprets MTG columns beyond the base
`GeometryConvention`: explicit coordinates, insertion fallback, biomechanical
stages, allometry preprocessing, and order-based defaults.

In normal use, create it with the keyword constructor
`AmapReconstructionOptions(; ...)` rather than by filling fields manually.
"""
struct AmapReconstructionOptions
    insertion_mode_aliases::Vector{Symbol}
    phyllotaxy_aliases::Vector{Symbol}
    verticil_mode::Symbol
    geometry_constraint_aliases::Vector{Symbol}
    coordinate_delegate_mode::Symbol
    azimuth_aliases::Vector{Symbol}
    elevation_aliases::Vector{Symbol}
    deviation_aliases::Vector{Symbol}
    orthotropy_aliases::Vector{Symbol}
    stiffness_angle_aliases::Vector{Symbol}
    stiffness_aliases::Vector{Symbol}
    stiffness_tapering_aliases::Vector{Symbol}
    stiffness_apply_aliases::Vector{Symbol}
    stiffness_straightening_aliases::Vector{Symbol}
    broken_aliases::Vector{Symbol}
    plagiotropy_aliases::Vector{Symbol}
    normal_up_aliases::Vector{Symbol}
    orientation_reset_aliases::Vector{Symbol}
    insertion_aliases::Vector{Symbol}
    endpoint_x_aliases::Vector{Symbol}
    endpoint_y_aliases::Vector{Symbol}
    endpoint_z_aliases::Vector{Symbol}
    allometry_enabled::Bool
    allometry_interpolate_width_height::Bool
    allometry_default_length::Float64
    allometry_default_width::Float64
    allometry_default_height::Float64
    order_attribute::Symbol
    auto_compute_branching_order::Bool
    insertion_y_by_order::Dict{Int,Float64}
    phyllotaxy_by_order::Dict{Int,Float64}
    order_override_mode::Symbol
end

@inline _amap_as_symbol(x::Symbol) = x
@inline _amap_as_symbol(x::AbstractString) = Symbol(x)

function _amap_normalize_aliases(values)
    [_amap_as_symbol(v) for v in values]
end

function _amap_normalize_order_map(values)
    out = Dict{Int,Float64}()
    for (k, v) in values
        out[Int(k)] = Float64(v)
    end
    out
end

"""
    AmapReconstructionOptions(; kwargs...)

Build the options object that controls the AMAP-style reconstruction pipeline.

Pass this object through the `amap_options=` keyword of:

```julia
set_geometry_from_attributes!(mtg, prototypes; amap_options=...)
reconstruct_geometry_from_attributes!(mtg, prototypes; amap_options=...)
rebuild_geometry!(mtg, prototypes; amap_options=...)
```

The constructor is organized around five kinds of settings:

1. alias lists: which MTG columns should be read for a given semantic
2. explicit-coordinate behavior: how `XX/YY/ZZ` and `EndX/EndY/EndZ` are interpreted
3. orientation and biomechanical stages: azimuth/elevation, stiffness, plagiotropy, constraints
4. allometry preprocessing: how missing size values are interpolated or propagated
5. order-based defaults: how branching order can supply default insertion/phyllotaxy values

Most users only need a few keywords:

- `explicit_coordinate_mode`
- `verticil_mode`
- `insertion_y_by_order`
- `phyllotaxy_by_order`
- `order_override_mode`

Keyword reference:

- `insertion_mode_aliases`
  Column names used to read insertion mode (`CENTER`, `BORDER`, `WIDTH`, `HEIGHT`).
  Change this if your MTG stores the same concept under different names.

- `phyllotaxy_aliases`
  Column names used to read phyllotaxy fallback. This is used mainly when
  insertion azimuth information is incomplete.

- `verticil_mode::Symbol=:rotation360`
  Controls sibling spread when `XInsertionAngle` is missing.
  Use `:rotation360` to distribute siblings around 360 degrees, or `:none` to
  disable this automatic spread.

- `geometry_constraint_aliases`
  Column names used to read geometric constraint specifications.
  Change this only if your dataset stores these constraints under custom names.

- `coordinate_delegate_mode::Union{Nothing,Symbol}=nothing`
  Legacy alias for `explicit_coordinate_mode`. Prefer `explicit_coordinate_mode`
  in new code. If both are provided, they must agree.

- `explicit_coordinate_mode::Union{Nothing,Symbol}=nothing`
  Controls how explicit coordinates are interpreted.
  Accepted values are:
  - `:topology_default`: `XX/YY/ZZ` sets the node base, but the node still
    behaves like a regular visible segment if endpoints are missing.
  - `:explicit_rewire_previous`: explicit coordinates act as control points that
    rewire the previous segment; the explicit node becomes a point-anchor.
  - `:explicit_start_end_required`: nodes with explicit coordinates are rebuilt
    strictly from start/end coordinates; incomplete endpoints are omitted.
  If omitted, the default is `:topology_default`.

- `azimuth_aliases`, `elevation_aliases`
  Column names used for world-space azimuth/elevation stages. Use these only if
  your MTG provides explicit orientation overrides in world coordinates.

- `deviation_aliases`
  Column names used for deviation-angle rotation. This is an extra world-space
  directional adjustment applied after the main insertion stage.

- `orthotropy_aliases`
  Column names used for orthotropy-driven bending orientation. This is a
  heuristic biomechanical orientation stage and is usually only relevant for
  datasets that provide such measurements.

- `stiffness_angle_aliases`
  Column names used for directly measured stiffness-angle values.
  When present, these take precedence over orthotropy-based bending direction.

- `stiffness_aliases`
  Column names used for propagated stiffness values (`Stifness`/`Stiffness`).
  These are used to derive component bending when direct stiffness angles are not
  already present.

- `stiffness_tapering_aliases`
  Column names used for stiffness tapering. This changes how curvature is
  distributed along the organ.

- `stiffness_apply_aliases`
  Column names used for toggling stiffness propagation to component children.
  Set the corresponding MTG column to false when you want to disable that
  propagation for a node.

- `stiffness_straightening_aliases`
  Column names used for straightening after a given relative position along the
  organ. Larger values preserve bending farther along the organ.

- `broken_aliases`
  Column names used for "broken segment" semantics. This forces downstream
  component bending to collapse after the break threshold.

- `plagiotropy_aliases`
  Column names used for plagiotropy projection.
  Use this when your reconstruction must be projected toward a preferred
  directional plane.

- `normal_up_aliases`
  Column names used for the `NormalUp` projection stage.
  This is mainly useful for dorsiventral organs such as leaves, where you want
  the organ normal to stay oriented toward world `+Z`.

- `orientation_reset_aliases`
  Column names used to reset the inherited local frame before insertion/euler
  stages. Use this when selected nodes should stop inheriting orientation from
  their parent frame.

- `insertion_aliases`
  Extra alias list for insertion semantics. This mainly exists for AMAP
  compatibility where some datasets use a shorter `Insertion` name.

- `endpoint_x_aliases`, `endpoint_y_aliases`, `endpoint_z_aliases`
  Column names used to read explicit endpoint coordinates.
  These matter only when your dataset supplies end coordinates or when
  `explicit_coordinate_mode` relies on them.

- `allometry_enabled::Bool=true`
  Enables the AMAP-style allometry preprocessing pass.
  When true, PlantGeom can interpolate, propagate, or infer missing length/width/
  height values before geometry stages.

- `allometry_interpolate_width_height::Bool=true`
  If true, missing width/height values can be interpolated along an axis.
  Disable this if you want missing cross-section values to remain missing unless
  explicitly measured or propagated.

- `allometry_default_length::Real=1.0`
  Default length assigned to terminal nodes when allometry is missing and no
  better estimate is available.

- `allometry_default_width::Real=1.0`
  Default width assigned to terminal nodes when allometry is missing and no
  better estimate is available.

- `allometry_default_height::Real=1.0`
  Default height/thickness assigned to terminal nodes when allometry is missing
  and no better estimate is available.

- `order_attribute=:branching_order`
  MTG attribute used to define branching order for order-based defaults.
  Change this if your graph already stores order under another attribute name.

- `auto_compute_branching_order::Bool=true`
  If true, PlantGeom computes branching order automatically when the chosen
  `order_attribute` is missing. Disable this if your dataset already provides the
  values and you do not want automatic recomputation.

- `insertion_y_by_order=Dict{Int,Float64}()`
  Mapping from branching order to default `YInsertionAngle`.
  Useful when higher-order axes should systematically be more erect or more
  horizontal.

- `phyllotaxy_by_order=Dict{Int,Float64}()`
  Mapping from branching order to default phyllotaxy.
  Useful when phyllotaxy is partly defined by organ order rather than measured
  node by node.

- `order_override_mode::Symbol=:override`
  Controls how order-based maps interact with measured attributes.
  Accepted values are:
  - `:override`: order-map values replace present node values
  - `:missing_only`: order-map values are used only when the node value is absent

Examples
========

Use explicit start/end coordinates strictly:

```julia
opts = AmapReconstructionOptions(
    explicit_coordinate_mode=:explicit_start_end_required,
)
```

Use order-based insertion defaults without overwriting measured values:

```julia
opts = AmapReconstructionOptions(
    insertion_y_by_order=Dict(2 => 35.0, 3 => 20.0),
    order_override_mode=:missing_only,
)
```

Use custom MTG column names for explicit coordinates:

```julia
opts = AmapReconstructionOptions(
    endpoint_x_aliases=[:tip_x, :EndX],
    endpoint_y_aliases=[:tip_y, :EndY],
    endpoint_z_aliases=[:tip_z, :EndZ],
)
```
"""
function AmapReconstructionOptions(;
    insertion_mode_aliases=[:InsertionMode, :insertion_mode, :Insertion, :insertion],
    phyllotaxy_aliases=[:Phyllotaxy, :phyllotaxy, :PHYLLOTAXY],
    verticil_mode::Symbol=:rotation360,
    geometry_constraint_aliases=[:GeometricalConstraint, :geometrical_constraint, :GeometryConstraint, :geometry_constraint],
    coordinate_delegate_mode::Union{Nothing,Symbol}=nothing,
    explicit_coordinate_mode::Union{Nothing,Symbol}=nothing,
    azimuth_aliases=[:Azimuth, :azimuth],
    elevation_aliases=[:Elevation, :elevation],
    deviation_aliases=[:DeviationAngle, :deviation_angle],
    orthotropy_aliases=[:Orthotropy, :orthotropy],
    stiffness_angle_aliases=[:StiffnessAngle, :stiffness_angle],
    stiffness_aliases=[:Stifness, :stifness, :Stiffness, :stiffness],
    stiffness_tapering_aliases=[:StifnessTapering, :stifness_tapering, :StiffnessTapering, :stiffness_tapering],
    stiffness_apply_aliases=[:StiffnessApply, :stiffness_apply],
    stiffness_straightening_aliases=[:StiffnessStraightening, :stiffness_straightening],
    broken_aliases=[:Broken, :broken],
    plagiotropy_aliases=[:Plagiotropy, :plagiotropy],
    normal_up_aliases=[:NormalUp, :normal_up],
    orientation_reset_aliases=[:OrientationReset, :orientation_reset, :Global, :global],
    insertion_aliases=[:Insertion, :insertion],
    endpoint_x_aliases=[:EndX, :end_x, :endx],
    endpoint_y_aliases=[:EndY, :end_y, :endy],
    endpoint_z_aliases=[:EndZ, :end_z, :endz],
    allometry_enabled::Bool=true,
    allometry_interpolate_width_height::Bool=true,
    allometry_default_length::Real=1.0,
    allometry_default_width::Real=1.0,
    allometry_default_height::Real=1.0,
    order_attribute=:branching_order,
    auto_compute_branching_order::Bool=true,
    insertion_y_by_order=Dict{Int,Float64}(),
    phyllotaxy_by_order=Dict{Int,Float64}(),
    order_override_mode::Symbol=:override,
)
    if coordinate_delegate_mode !== nothing &&
       explicit_coordinate_mode !== nothing &&
       coordinate_delegate_mode != explicit_coordinate_mode
        error(
            "Received conflicting coordinate mode options: coordinate_delegate_mode=$coordinate_delegate_mode and explicit_coordinate_mode=$explicit_coordinate_mode.",
        )
    end
    effective_coordinate_mode = if explicit_coordinate_mode !== nothing
        explicit_coordinate_mode
    elseif coordinate_delegate_mode !== nothing
        coordinate_delegate_mode
    else
        :topology_default
    end

    verticil_mode in (:rotation360, :none) ||
        error("Invalid verticil_mode '$verticil_mode'. Expected :rotation360 or :none.")
    effective_coordinate_mode in (:topology_default, :explicit_rewire_previous, :explicit_start_end_required) ||
        error(
            "Invalid explicit-coordinate handling mode '$effective_coordinate_mode'. Expected :topology_default, :explicit_rewire_previous or :explicit_start_end_required.",
        )
    order_override_mode in (:override, :missing_only) ||
        error("Invalid order_override_mode '$order_override_mode'. Expected :override or :missing_only.")

    AmapReconstructionOptions(
        _amap_normalize_aliases(insertion_mode_aliases),
        _amap_normalize_aliases(phyllotaxy_aliases),
        verticil_mode,
        _amap_normalize_aliases(geometry_constraint_aliases),
        effective_coordinate_mode,
        _amap_normalize_aliases(azimuth_aliases),
        _amap_normalize_aliases(elevation_aliases),
        _amap_normalize_aliases(deviation_aliases),
        _amap_normalize_aliases(orthotropy_aliases),
        _amap_normalize_aliases(stiffness_angle_aliases),
        _amap_normalize_aliases(stiffness_aliases),
        _amap_normalize_aliases(stiffness_tapering_aliases),
        _amap_normalize_aliases(stiffness_apply_aliases),
        _amap_normalize_aliases(stiffness_straightening_aliases),
        _amap_normalize_aliases(broken_aliases),
        _amap_normalize_aliases(plagiotropy_aliases),
        _amap_normalize_aliases(normal_up_aliases),
        _amap_normalize_aliases(orientation_reset_aliases),
        _amap_normalize_aliases(insertion_aliases),
        _amap_normalize_aliases(endpoint_x_aliases),
        _amap_normalize_aliases(endpoint_y_aliases),
        _amap_normalize_aliases(endpoint_z_aliases),
        allometry_enabled,
        allometry_interpolate_width_height,
        Float64(allometry_default_length),
        Float64(allometry_default_width),
        Float64(allometry_default_height),
        _amap_as_symbol(order_attribute),
        auto_compute_branching_order,
        _amap_normalize_order_map(insertion_y_by_order),
        _amap_normalize_order_map(phyllotaxy_by_order),
        order_override_mode,
    )
end

"""
    default_amap_reconstruction_options()

Return `AmapReconstructionOptions()` with the default AMAP-compatible settings.

Use this when your MTG follows the default AMAP naming/profile and you do not
need to customize explicit-coordinate behavior or order-based defaults.
"""
function default_amap_reconstruction_options()
    AmapReconstructionOptions()
end
