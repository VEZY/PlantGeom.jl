@eval using PlantSimEngine
@eval using PlantSimEngine.Examples

@eval begin
    PlantSimEngine.@process "plantgeom_test_emergence" verbose = false

    struct PlantGeomTestEmergenceModel <: AbstractPlantgeom_Test_EmergenceModel
        TT_emergence::Float64
    end

    PlantGeomTestEmergenceModel(; TT_emergence=10.0) =
        PlantGeomTestEmergenceModel(TT_emergence)

    PlantSimEngine.inputs_(::PlantGeomTestEmergenceModel) = (TT_cu=-Inf,)
    PlantSimEngine.outputs_(::PlantGeomTestEmergenceModel) =
        (TT_cu_emergence=0.0, emitted=0,)

    function PlantSimEngine.run!(
        model::PlantGeomTestEmergenceModel,
        models,
        status,
        meteo,
        constants=nothing,
        context=nothing,
    )
        status.emitted == 0 || return nothing
        status.TT_cu - status.TT_cu_emergence >= model.TT_emergence || return nothing

        phase = isodd(length(PlantSimEngine.model_objects(context.compiled.scene; scale=:Internode))) ?
                180.0 : 0.0
        emit_phytomer!(
            status,
            context;
            internode=(
                length=0.16,
                width=0.015,
                thickness=0.015,
                prototype=:Internode,
                initial_status=(TT_cu_emergence=status.TT_cu, emitted=0),
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
            bump_scene=false,
        )

        status.TT_cu_emergence = status.TT_cu
        status.emitted = 1
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

    function initial_status(node)
        data = Dict{Symbol,Any}(:node => node)
        for (key, value) in pairs(MultiScaleTreeGraph.node_attributes(node))
            data[Symbol(key)] = value
        end
        if MultiScaleTreeGraph.symbol(node) == :Internode
            data[:TT_cu_emergence] = 0.0
            data[:emitted] = 0
        end
        status = PlantSimEngine.Status((; data...))
        node[:plantsimengine_status] = status
        return status
    end

    meteo = Weather(
        [
            Atmosphere(T=20.0, Wind=1.0, Rh=0.65),
            Atmosphere(T=20.0, Wind=1.0, Rh=0.65),
            Atmosphere(T=20.0, Wind=1.0, Rh=0.65),
        ],
    )
    scene = PlantSimEngine.CompositeModel(
        mtg;
        status=initial_status,
        environment=meteo,
        applications=(
            PlantSimEngine.ModelSpec(ToyDegreeDaysCumulModel(); name=:degree_days) |>
            PlantSimEngine.AppliesTo(PlantSimEngine.One(scale=:Scene)),
            PlantSimEngine.ModelSpec(
                PlantGeomTestEmergenceModel(TT_emergence=10.0);
                name=:emergence,
            ) |>
            PlantSimEngine.AppliesTo(PlantSimEngine.Many(scale=:Internode)) |>
            PlantSimEngine.Inputs(
                :TT_cu => PlantSimEngine.One(
                    scale=:Scene,
                    within=PlantSimEngine.SceneScope(),
                    var=:TT_cu,
                ),
            ),
        ),
    )
    simulation = @test_nowarn PlantSimEngine.run!(
        scene;
        steps=3,
        tracked_outputs=PlantSimEngine.OutputRequest(
            :Internode,
            :TT_cu_emergence;
            name=:internode_emergence,
        ),
    )

    internodes = PlantSimEngine.model_objects(scene; scale=:Internode)
    leaves = PlantSimEngine.model_objects(scene; scale=:Leaf)
    @test length(internodes) == 4
    @test length(leaves) == 4
    @test only(PlantSimEngine.model_objects(scene; scale=:Scene)).status.TT_cu ≈ 30.0
    @test first(internodes).status.emitted == 1
    emergence_times = sort([object.status.TT_cu_emergence for object in internodes])
    @test emergence_times[end] ≈ 30.0
    @test all(time >= 0.0 for time in emergence_times)

    last_leaf = last(leaves).status.node
    @test last_leaf[:GeometryPrototype] == :Leaf
    @test last_leaf[:GeometryPrototypeOverrides] == (bend=0.32, tip_drop=0.10)

    prototypes = _plantsimengine_growth_test_prototypes()
    rebuild_geometry!(mtg, prototypes; bump_scene=false)

    @test all(PlantGeom.has_geometry(object.status.node) for object in internodes)
    @test all(PlantGeom.has_geometry(object.status.node) for object in leaves)

    output_rows = PlantSimEngine.collect_outputs(
        simulation,
        :internode_emergence;
        sink=nothing,
    )
    @test maximum(row.value for row in output_rows) ≈ 30.0
end
