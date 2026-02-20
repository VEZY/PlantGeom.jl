struct AmapReconstructionOptions
    insertion_mode_aliases::Vector{Symbol}
    phyllotaxy_aliases::Vector{Symbol}
    verticil_mode::Symbol
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

function AmapReconstructionOptions(;
    insertion_mode_aliases=[:InsertionMode, :insertion_mode, :Insertion, :insertion],
    phyllotaxy_aliases=[:Phyllotaxy, :phyllotaxy, :PHYLLOTAXY],
    verticil_mode::Symbol=:rotation360,
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
    order_attribute=:branching_order,
    auto_compute_branching_order::Bool=true,
    insertion_y_by_order=Dict{Int,Float64}(),
    phyllotaxy_by_order=Dict{Int,Float64}(),
    order_override_mode::Symbol=:override,
)
    verticil_mode in (:rotation360, :none) ||
        error("Invalid verticil_mode '$verticil_mode'. Expected :rotation360 or :none.")
    order_override_mode in (:override, :missing_only) ||
        error("Invalid order_override_mode '$order_override_mode'. Expected :override or :missing_only.")

    AmapReconstructionOptions(
        _amap_normalize_aliases(insertion_mode_aliases),
        _amap_normalize_aliases(phyllotaxy_aliases),
        verticil_mode,
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
        _amap_as_symbol(order_attribute),
        auto_compute_branching_order,
        _amap_normalize_order_map(insertion_y_by_order),
        _amap_normalize_order_map(phyllotaxy_by_order),
        order_override_mode,
    )
end

function default_amap_reconstruction_options()
    AmapReconstructionOptions()
end
