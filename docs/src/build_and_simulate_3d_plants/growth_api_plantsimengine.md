# Growth API with PlantSimEngine

!!! info "Page Info"
    - **Audience:** Intermediate
    - **Prerequisites:** [`Growth API`](@ref "Growth API")
    - **Time:** 20 minutes
    - **Output:** full PlantSimEngine-driven growth example with meteo, `run!`, and 3D reconstruction

This page shows the full **structure-function coupling** workflow:

- PlantSimEngine decides **when** a growth event happens
- PlantGeom creates the new organs with `emit_*`
- PlantGeom later rebuilds the geometry with `rebuild_geometry!`

The point of this workflow is to keep the responsibilities separate:

- **PlantSimEngine** owns statuses, model execution, meteorology, and `run!`
- **PlantGeom** owns topology edits and geometry metadata

## What this example does

We build a very small dynamic plant model where:

- a `:Scene` node accumulates thermal time from meteorology
- each internode emits **one new phytomer** once enough thermal time has accumulated
- the growth event is implemented inside a PlantSimEngine model using `emit_phytomer!`
- after the simulation, we rebuild geometry and visualize the result

This example is fully runnable as shown.

```@setup psegrowth
using PlantGeom
using PlantSimEngine
using MultiScaleTreeGraph
using GeometryBasics
using CairoMakie
using Colors
```

## 1. Load packages

```@example psegrowth
using PlantGeom
using PlantSimEngine
using MultiScaleTreeGraph
using GeometryBasics
using CairoMakie
using Colors
```

## 2. Define geometry prototypes

These prototypes are used only after the simulation, when we materialize geometry from the MTG attributes.

```@example psegrowth
stem_ref = RefMesh(
    "stem",
    GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            0.5,
        ),
    ),
    RGB(0.56, 0.43, 0.30),
)

leaf_ref = lamina_refmesh(
    "leaf";
    length=1.0,
    max_width=1.0,
    n_long=30,
    n_half=6,
    material=RGB(0.18, 0.58, 0.26),
)

prototypes = Dict(
    :Internode => RefMeshPrototype(stem_ref),
    :Leaf => PointMapPrototype(
        leaf_ref;
        defaults=(base_angle_deg=40.0, bend=0.24, tip_drop=0.07),
        attr_aliases=(
            base_angle_deg=(:base_angle_deg, :BaseAngle),
            bend=(:bend, :Bend),
            tip_drop=(:tip_drop, :TipDrop),
        ),
        intrinsic_shape=params -> LaminaMidribMap(
            base_angle_deg=params.base_angle_deg,
            bend=params.bend,
            tip_drop=params.tip_drop,
        ),
    ),
)
```

## 3. Define a PlantSimEngine growth model

This is the key integration point.

The model receives `TT_cu` from the `:Scene` scale.  
When the thermal-time threshold is reached, it calls `emit_phytomer!` from PlantGeom.

```@example psegrowth
PlantSimEngine.@process "plantgeom_docs_emergence" verbose = false

struct PlantGeomDocsEmergenceModel <: AbstractPlantgeom_Docs_EmergenceModel
    TT_emergence::Float64
end

PlantGeomDocsEmergenceModel(; TT_emergence=10.0) = PlantGeomDocsEmergenceModel(TT_emergence)

PlantSimEngine.inputs_(::PlantGeomDocsEmergenceModel) = (TT_cu=-Inf,)
PlantSimEngine.outputs_(::PlantGeomDocsEmergenceModel) = (TT_cu_emergence=0.0, emitted=0,)

function PlantSimEngine.run!(
    m::PlantGeomDocsEmergenceModel,
    models,
    status,
    meteo,
    constants=nothing,
    sim_object=nothing,
)
    if status.emitted == 0 && status.TT_cu - status.TT_cu_emergence >= m.TT_emergence
        # Count the number of internodes already emitted to alternate phyllotaxy:
        phase = isodd(length(sim_object.statuses[:Internode])) ? 180.0 : 0.0
        println("Emitting new phytomer at node $(status.node) with phase $phase")
        new_organs = emit_phytomer!(
            status,
            sim_object;
            internode=(
                length=0.16,
                width=0.015,
                thickness=0.015,
                prototype=:Internode,
            ),
            leaf=(
                length=0.24,
                width=0.050,
                thickness=0.008,
                offset=0.12,
                phyllotaxy=phase,
                y_insertion_angle=54.0,
                prototype=:Leaf,
                prototype_overrides=(bend=0.32, tip_drop=0.10),
            ),
            internode_index=1,
            leaf_index=1,
            check=true,
            bump_scene=false,
        )

        status.TT_cu_emergence = status.TT_cu
        status.emitted = 1

        if new_organs.internode !== nothing
            new_organs.internode.TT_cu_emergence = status.TT_cu
            new_organs.internode.emitted = 0
        end
    end

    return nothing
end
```

What this model is doing:

- each internode can emit only once (`status.emitted == 0`)
- the growth trigger is purely functional: `TT_cu - TT_cu_emergence >= TT_emergence`
- the new organs are created through the PlantGeom API, not by calling `add_organ!` manually

## 4. Build the initial MTG

We start from a very small graph:

- one `:Scene`
- one `:Plant`
- one initial `:Internode`
- one initial `:Leaf`

```@example psegrowth
mtg = Node(NodeMTG(:/, :Scene, 1, 0))
plant = Node(mtg, NodeMTG(:+, :Plant, 1, 1))

internode = Node(plant, NodeMTG(:/, :Internode, 1, 2))
internode[:Length] = 0.18
internode[:Width] = 0.020
internode[:Thickness] = 0.020
internode[:GeometryPrototype] = :Internode

leaf = Node(internode, NodeMTG(:+, :Leaf, 1, 2))
leaf[:Length] = 0.22
leaf[:Width] = 0.045
leaf[:Thickness] = 0.008
leaf[:Offset] = 0.13
leaf[:Phyllotaxy] = 0.0
leaf[:YInsertionAngle] = 50.0
leaf[:GeometryPrototype] = :Leaf
leaf[:GeometryPrototypeOverrides] = (bend=0.20, tip_drop=0.05)

mtg
```

## 5. Create the PlantSimEngine model mapping

This is where PlantSimEngine decides which models and status templates apply to each scale.

```@example psegrowth
mapping = PlantSimEngine.ModelMapping(
    :Scene => (
        ToyDegreeDaysCumulModel(),
    ),
    :Internode => (
        MultiScaleModel(
            model=PlantGeomDocsEmergenceModel(TT_emergence=10.0),
            mapped_variables=[:TT_cu => (:Scene => :TT_cu)],
        ),
        PlantSimEngine.Status(
            TT_cu=0.0,
            TT_cu_emergence=0.0,
            emitted=0,
            Length=0.0,
            Width=0.0,
            Thickness=0.0,
        ),
    )
)
```

Important detail:

- the growth model is attached to `:Internode`
- new internodes and leaves created during the simulation receive their status templates from this mapping. In this example, no model is attached to `:Leaf`, but you could add one if you wanted to simulate leaf growth dynamics instead of just emergence.

## 6. Define meteo and run the simulation

Here we use a very small weather series.  
With `T = 20°C` and the default `ToyDegreeDaysCumulModel(T_base=10)`, each step contributes `10` degree-days.

```@example psegrowth
meteo = Weather(
    [
        Atmosphere(T=20.0, Wind=1.0, Rh=0.65),
        Atmosphere(T=20.0, Wind=1.0, Rh=0.65),
        Atmosphere(T=20.0, Wind=1.0, Rh=0.65),
    ],
)

sim = PlantSimEngine.GraphSimulation(
    mtg,
    mapping;
    nsteps=PlantSimEngine.get_nsteps(meteo),
    outputs=Dict(
        :Scene => (:TT_cu,),
        :Internode => (:TT_cu_emergence, :emitted),
    ),
    check=true,
)

outputs = run!(sim, meteo, executor=PlantSimEngine.SequentialEx())
(
    scene_TT_cu=sim.statuses[:Scene][1].TT_cu,
    n_internodes=length(sim.statuses[:Internode]),
    emergence_times=[st.TT_cu_emergence for st in sim.statuses[:Internode]],
)
```

At this stage, the simulation has changed the plant topology and initialized the new statuses, but geometry has not yet been rebuilt.

## 7. Rebuild geometry and visualize the resulting plant

```@example psegrowth
rebuild_geometry!(mtg, prototypes)

plantviz(mtg)
```

## What to remember

This example shows the intended split:

- PlantSimEngine models decide **when** growth happens
- PlantGeom functions decide **how** new organs are created in the MTG
- `rebuild_geometry!` remains explicit, even in a structure-function workflow

So the recommended pattern is:

1. write a PlantSimEngine model that triggers growth events
2. call `emit_internode!`, `emit_leaf!`, or `emit_phytomer!` inside that model
3. run the simulation with `run!(sim, meteo)`
4. rebuild geometry when you want a visual or exportable 3D plant
