@eval using PlantSimEngine
@eval using PlantSimEngine.Examples

@eval begin
    PlantSimEngine.@process "plantgeom_test_emergence" verbose = false

    struct PlantGeomTestEmergenceModel <: AbstractPlantgeom_Test_EmergenceModel
        TT_emergence::Float64
    end

    PlantGeomTestEmergenceModel(; TT_emergence=10.0) = PlantGeomTestEmergenceModel(TT_emergence)

    PlantSimEngine.inputs_(::PlantGeomTestEmergenceModel) = (TT_cu=-Inf,)
    PlantSimEngine.outputs_(::PlantGeomTestEmergenceModel) = (TT_cu_emergence=0.0, emitted=0,)

    function PlantSimEngine.run!(
        m::PlantGeomTestEmergenceModel,
        models,
        status,
        meteo,
        constants=nothing,
        sim_object=nothing,
    )
        if status.emitted == 0 && status.TT_cu - status.TT_cu_emergence >= m.TT_emergence
            # Count the number of internodes already emitted to alternate phyllotaxy:
            phase = isodd(length(sim_object.statuses[:Internode])) ? 180.0 : 0.0
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
end

function _plantsimengine_growth_test_graph()
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

    return mtg
end

function _plantsimengine_growth_test_prototypes()
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
        n_long=24,
        n_half=6,
        material=RGB(0.18, 0.58, 0.26),
    )

    return Dict(
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
end

@testset "Growth API PlantSimEngine simulation" begin
    mtg = _plantsimengine_growth_test_graph()

    mapping = PlantSimEngine.ModelMapping(
        :Scene => (
            ToyDegreeDaysCumulModel(),
        ),
        :Plant => (
            Process1Model(0.0),
            PlantSimEngine.Status(var1=0.0, var2=0.0),
        ),
        :Internode => (
            MultiScaleModel(
                model=PlantGeomTestEmergenceModel(TT_emergence=10.0),
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
        ),
        :Leaf => (
            Process1Model(0.0),
            PlantSimEngine.Status(
                var1=0.0,
                var2=0.0,
                Length=0.0,
                Width=0.0,
                Thickness=0.0,
            ),
        ),
    )

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

    outputs = @test_nowarn run!(sim, meteo, executor=PlantSimEngine.SequentialEx())

    @test length(sim.statuses[:Internode]) == 4
    @test length(sim.statuses[:Leaf]) == 4
    @test sim.statuses[:Scene][1].TT_cu ≈ 30.0
    @test sim.statuses[:Internode][1].emitted == 1
    emergence_times = [st.TT_cu_emergence for st in sim.statuses[:Internode]]
    @test issorted(emergence_times)
    @test emergence_times[end] ≈ 30.0
    @test all(t >= 0.0 for t in emergence_times)

    last_leaf = sim.statuses[:Leaf][end].node
    @test last_leaf[:GeometryPrototype] == :Leaf
    @test last_leaf[:GeometryPrototypeOverrides] == (bend=0.32, tip_drop=0.10)

    prototypes = _plantsimengine_growth_test_prototypes()
    rebuild_geometry!(mtg, prototypes; bump_scene=false)

    @test all(PlantGeom.has_geometry(st.node) for st in sim.statuses[:Internode])
    @test all(PlantGeom.has_geometry(st.node) for st in sim.statuses[:Leaf])

    @test outputs[:Internode][end].TT_cu_emergence ≈ 30.0
end
