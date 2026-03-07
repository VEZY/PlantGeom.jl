# Growth API

The Growth API is designed for explicit, readable Julia simulations:

- build and mutate structure at node scale
- control exactly when geometry is rebuilt
- optionally couple growth events with `PlantSimEngine` statuses through extension methods

```@setup growth_api
using PlantGeom
using MultiScaleTreeGraph
using GeometryBasics
using Colors
using CairoMakie

CairoMakie.activate!()

function growth_prototypes()
    leaf_base = lamina_refmesh(
        "leaf_base";
        length=1.0,
        max_width=1.0,
        n_long=40,
        n_half=8,
        material=RGB(0.20, 0.60, 0.22),
    )

    leaf_ref_with_maps = function (
        name;
        base_angle_deg,
        bend,
        tip_drop,
        tip_twist_deg,
        roll_strength,
        wave_amp,
        wave_len,
        phase_deg,
        asymmetry=0.10,
        color=RGB(0.18, 0.62, 0.27),
    )
        point_map = compose_point_maps(
            LaminaAnticlasticWaveMap(
                amplitude=wave_amp / 0.12,
                wavelength=wave_len,
                edge_exponent=1.6,
                progression_exponent=1.1,
                base_damping=5.0,
                phase_deg=phase_deg,
                asymmetry=asymmetry,
                lateral_strength=0.0,
                vertical_strength=1.0,
            ),
            LaminaTwistRollMap(
                tip_twist_deg=tip_twist_deg,
                roll_strength=roll_strength,
                roll_exponent=1.2,
            ),
            LaminaMidribMap(
                base_angle_deg=base_angle_deg,
                bend=bend,
                tip_drop=tip_drop,
            ),
        )
        geom = PointMappedGeometry(leaf_base, point_map)
        RefMesh(name, PlantGeom.geometry_to_mesh(geom), color)
    end

    leaf_juvenile_ref = leaf_ref_with_maps(
        "leaf_juvenile";
        base_angle_deg=18.0,
        bend=0.18,
        tip_drop=0.05,
        tip_twist_deg=8.0,
        roll_strength=0.18,
        wave_amp=0.008,
        wave_len=0.23,
        phase_deg=25.0,
        color=RGB(0.40, 0.78, 0.36),
    )
    leaf_expanding_ref = leaf_ref_with_maps(
        "leaf_expanding";
        base_angle_deg=30.0,
        bend=0.40,
        tip_drop=0.11,
        tip_twist_deg=18.0,
        roll_strength=0.30,
        wave_amp=0.010,
        wave_len=0.19,
        phase_deg=50.0,
        color=RGB(0.26, 0.68, 0.32),
    )
    leaf_adult_ref = leaf_ref_with_maps(
        "leaf_adult";
        base_angle_deg=44.0,
        bend=0.74,
        tip_drop=0.24,
        tip_twist_deg=34.0,
        roll_strength=0.44,
        wave_amp=0.012,
        wave_len=0.15,
        phase_deg=75.0,
        color=RGB(0.18, 0.62, 0.27),
    )

    stem_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            0.5,
        ),
    )

    Dict(
        :Internode => RefMesh("stem", stem_mesh, RGB(0.46, 0.36, 0.24)),
        :Leaf => leaf_adult_ref,
        :LeafExpanding => leaf_expanding_ref,
        :LeafJuvenile => leaf_juvenile_ref,
    )
end
```

## Public functions

### Structure-only mode (core PlantGeom)

| Function | Purpose |
|---|---|
| `emit_internode!(parent; kwargs...) -> Node` | Add an `:Internode` child node and set growth attributes (`Length`, `Width`, insertion/euler attrs, custom attrs, optional `prototype`, and `prototype_overrides`). |
| `emit_leaf!(parent; kwargs...) -> Node` | Add a `:Leaf` child node and set growth attributes (including stage/age, optional `prototype`, and `prototype_overrides`). |
| `emit_phytomer!(parent; internode=..., leaf=..., ...) -> NamedTuple` | Emit one internode and one leaf in one call; returns `(internode=..., leaf=...)`. |
| `grow_length!(x; delta, bump_scene=true) -> x` | Increment `:Length` by `delta` on a node-like object. |
| `grow_width!(x; delta, thickness_policy=:follow_width, bump_scene=true) -> x` | Increment `:Width`, and optionally sync/update `:Thickness`. |
| `set_growth_attributes!(x; kwargs..., bump_scene=true) -> x` | Set arbitrary attributes on the target node. |
| `rebuild_geometry!(mtg, prototypes; ..., prototype_selector=nothing, prototype_overrides=nothing, bump_scene=true) -> mtg` | Recompute per-node geometry from attributes and prototypes. |

Key defaults:
- `emit_internode!` defaults `link=:<`; use `link=:/` for the first axis node.
- `emit_leaf!` defaults `link=:+`.
- `azimuth=...` is accepted as an alias of `phyllotaxy=...` in `emit_internode!` and `emit_leaf!`.
- if `thickness` is omitted and `width` is provided, emitted organs default `Thickness = Width`.
- `Length`, `Width`, and `Thickness` are multiplicative scale factors applied to the selected `RefMesh`.
- cereal point-map examples use normalized leaf refs (`max_width=1.0`) so `Width`/`Thickness` are intuitive physical scalars.
- geometry is never rebuilt implicitly by emit/grow helpers.

### PlantSimEngine-coupled mode (extension)

When `PlantGeom` and `PlantSimEngine` are both loaded, extra overloads are available:

- `emit_internode!(parent::Node, sim::GraphSimulation; ...) -> Status`
- `emit_internode!(parent_status::Status, sim::GraphSimulation; ...) -> Status`
- `emit_leaf!(...)` with the same two parent forms
- `emit_phytomer!(...)` with the same two parent forms

These overloads delegate to `PlantSimEngine.add_organ!`, so status initialization remains owned by PlantSimEngine.
Also, `grow_length!`, `grow_width!`, and `set_growth_attributes!` accept `PlantSimEngine.Status` and update `status.node`.

## Example 1: manual structure edits + explicit geometry rebuild

```@example growth_api
mtg = Node(NodeMTG(:/, :Plant, 1, 1))
prototypes = growth_prototypes()

axis = emit_internode!(
    mtg;
    index=1,
    link=:/,
    length=0.21,
    width=0.017,
    y_euler=0.0,
)
leaf = emit_leaf!(
    axis;
    index=1,
    length=0.27,
    width=0.034,
    y_insertion_angle=50.0,
    phyllotaxy=0.0,
    x_euler=-20.0,
    leaf_stage=:juvenile,
    age=0,
)
phy = emit_phytomer!(
    axis;
    internode=(
        index=2,
        length=0.17,
        width=0.013,
        y_euler=0.0,
    ),
    leaf=(
        index=2,
        length=0.24,
        width=0.030,
        y_insertion_angle=52.0,
        phyllotaxy=180.0,
        x_euler=-18.0,
        leaf_stage=:adult,
        age=2,
    ),
)

grow_length!(phy.internode; delta=0.015)
grow_width!(phy.internode; delta=0.0015, thickness_policy=:follow_width)
set_growth_attributes!(leaf; leaf_stage=:expanding, age=1)

selector = node -> begin
    symbol(node) == :Leaf || return nothing
    stage = haskey(node, :leaf_stage) ? node[:leaf_stage] : :adult
    stage == :juvenile && return prototypes[:LeafJuvenile]
    stage == :expanding && return prototypes[:LeafExpanding]
    nothing
end

rebuild_geometry!(mtg, prototypes; prototype_selector=selector)
fig = Figure(size=(760, 520))
ax = Axis3(
    fig[1, 1],
    aspect=:data,
    azimuth=1.12pi,
    elevation=0.34,
    perspectiveness=0.72,
)
plantviz!(
    ax,
    mtg,
    color=Dict("Internode" => RGB(0.50, 0.36, 0.24), "Leaf" => RGB(0.20, 0.64, 0.30)),
)
autolimits!(ax)
hidedecorations!(ax)
hidespines!(ax)
fig
```

## Example 2: loop-driven cereal-like growth (node scale)

```@example growth_api
cereal = Node(NodeMTG(:/, :Plant, 1, 1))
leaf_specs = [
    (z=0.20, azimuth_deg=-35.0, base_angle_deg=18.0, bend=0.18, tip_drop=0.05, twist=8.0, roll=0.18, wave_amp=0.008, wave_len=0.23, phase_deg=25.0, scale=0.82),
    (z=0.56, azimuth_deg=84.0, base_angle_deg=30.0, bend=0.40, tip_drop=0.11, twist=18.0, roll=0.30, wave_amp=0.010, wave_len=0.19, phase_deg=50.0, scale=0.96),
    (z=0.90, azimuth_deg=208.0, base_angle_deg=44.0, bend=0.74, tip_drop=0.24, twist=34.0, roll=0.44, wave_amp=0.012, wave_len=0.15, phase_deg=75.0, scale=1.05),
    (z=1.26, azimuth_deg=6.0, base_angle_deg=72.0, bend=0.28, tip_drop=0.06, twist=10.0, roll=0.20, wave_amp=0.008, wave_len=0.20, phase_deg=10.0, scale=0.76),
]

blade_ref = lamina_refmesh(
    "CerealBlade";
    length=1.0,
    max_width=1.0,
    n_long=40,
    n_half=8,
    material=RGB(0.20, 0.60, 0.22),
)
stem_mesh = GeometryBasics.mesh(
    GeometryBasics.Cylinder(
        Point(0.0, 0.0, 0.0),
        Point(1.0, 0.0, 0.0),
        0.5,
    ),
)
prototypes = Dict{Any,RefMesh}(
    :Internode => RefMesh("stem", stem_mesh, RGB(0.54, 0.76, 0.38)),
)

make_leaf_ref = function (name, spec)
    point_map = compose_point_maps(
        LaminaAnticlasticWaveMap(
            amplitude=spec.wave_amp / 0.12,
            wavelength=spec.wave_len,
            edge_exponent=1.6,
            progression_exponent=1.1,
            base_damping=5.0,
            phase_deg=spec.phase_deg,
            asymmetry=0.10,
            lateral_strength=0.0,
            vertical_strength=1.0,
        ),
        LaminaTwistRollMap(
            tip_twist_deg=spec.twist,
            roll_strength=spec.roll,
            roll_exponent=1.2,
        ),
        LaminaMidribMap(
            base_angle_deg=spec.base_angle_deg,
            bend=spec.bend,
            tip_drop=spec.tip_drop,
        ),
    )
    RefMesh(name, PlantGeom.geometry_to_mesh(PointMappedGeometry(blade_ref, point_map)), RGB(0.20, 0.60, 0.22))
end

culm = emit_internode!(cereal; index=1, link=:/, length=1.26, width=0.022, y_euler=0.0)
let
    step = 1
    while step <= length(leaf_specs)
        spec = leaf_specs[step]
        ref_key = Symbol("LeafRef", step)
        prototypes[ref_key] = make_leaf_ref(String(ref_key), spec)

        emit_leaf!(
            culm;
        index=step,
        offset=spec.z,
        length=spec.scale,
        width=0.12 * spec.scale,
        thickness=0.12 * spec.scale,
        phyllotaxy=spec.azimuth_deg,
        y_insertion_angle=55.0,
        leaf_ref=ref_key,
        )
        step += 1
    end
end

selector = node -> begin
    symbol(node) == :Leaf || return nothing
    haskey(node, :leaf_ref) ? prototypes[node[:leaf_ref]] : nothing
end

rebuild_geometry!(cereal, prototypes; prototype_selector=selector)
fig = Figure(size=(880, 620))
ax = Axis3(
    fig[1, 1],
    aspect=:data,
    azimuth=1.12pi,
    elevation=0.34,
    perspectiveness=0.72,
)
plantviz!(
    ax,
    cereal,
    color=Dict("Internode" => RGB(0.54, 0.76, 0.38), "Leaf" => RGB(0.20, 0.60, 0.22)),
)
autolimits!(ax)
hidedecorations!(ax)
hidespines!(ax)
fig
```

## Rebuild cadence and performance

For simulation performance, keep geometry rebuild explicit and controlled:

- run many topology/attribute updates per step
- call `rebuild_geometry!` only at your chosen output cadence (for example every N steps, or only when exporting/plotting)
- keep `bump_scene=true` (default) if you rely on cached merged scenes for plotting updates

## PlantSimEngine example (extension)

```julia
using PlantGeom
using PlantSimEngine

# inside a PlantSimEngine model run!:
new_internode_status = emit_internode!(status.node, sim_object; length=0.03, width=0.004)
new_leaf_status = emit_leaf!(new_internode_status, sim_object; length=0.10, width=0.03, leaf_stage=:juvenile)
grow_length!(new_internode_status; delta=0.005)
set_growth_attributes!(new_leaf_status; leaf_stage=:expanding, age=1)
```
