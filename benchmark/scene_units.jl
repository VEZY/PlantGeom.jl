using BenchmarkTools
using GeometryBasics
using MultiScaleTreeGraph
using PlantGeom
using Unitful

function scene_units_one_face_plant(n_organs::Int=1000)
    mesh = GeometryBasics.Mesh(
        GeometryBasics.Point{3,Float64}[
            GeometryBasics.Point(0.0, 0.0, 0.0),
            GeometryBasics.Point(1.0, 0.0, 0.0),
            GeometryBasics.Point(0.0, 1.0, 0.0),
        ],
        GeometryBasics.TriangleFace{Int}[
            GeometryBasics.TriangleFace{Int}(1, 2, 3),
        ],
    )
    shared_ref = RefMesh("scene-units-one-face", mesh)
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    for i in 1:n_organs
        Node(
            i + 1,
            plant,
            NodeMTG(:+, :Leaf, i, 2),
            Dict{Symbol,Any}(
                :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
            ),
        )
    end
    return plant
end

function scene_units_make_scene_default(plant)
    make_scene(
        domain=(0.0, 0.0, 2.0, 2.0),
        compute_area=false,
        compute_barycenter=false,
        source_topology_id=false,
    ) do builder
        add_plant!(builder, plant; group="plants", id=1)
    end
end

function scene_units_make_scene_same_unit(plant)
    make_scene(
        domain=(0.0, 0.0, 2.0, 2.0),
        compute_area=false,
        compute_barycenter=false,
        source_topology_id=false,
    ) do builder
        add_plant!(
            builder,
            plant;
            group="plants",
            id=1,
            geometry_length_unit=u"m",
        )
    end
end

function scene_units_make_scene_converted(plant)
    make_scene(
        domain=(0.0, 0.0, 2.0, 2.0),
        compute_area=false,
        compute_barycenter=false,
        source_topology_id=false,
    ) do builder
        add_plant!(
            builder,
            plant;
            group="plants",
            id=1,
            geometry_length_unit=u"cm",
        )
    end
end

const SCENE_UNITS_TEMPLATE = scene_units_one_face_plant()
const SCENE_UNITS_SUITE = BenchmarkGroup()
SCENE_UNITS_SUITE["make_scene, no unit conversion"] =
    @benchmarkable scene_units_make_scene_default($SCENE_UNITS_TEMPLATE) evals = 1
SCENE_UNITS_SUITE["make_scene, declared identical unit"] =
    @benchmarkable scene_units_make_scene_same_unit($SCENE_UNITS_TEMPLATE) evals = 1
SCENE_UNITS_SUITE["make_scene, cm to m conversion"] =
    @benchmarkable scene_units_make_scene_converted($SCENE_UNITS_TEMPLATE) evals = 1

if abspath(PROGRAM_FILE) == @__FILE__
    BenchmarkTools.tune!(SCENE_UNITS_SUITE)
    display(BenchmarkTools.run(SCENE_UNITS_SUITE; verbose=true))
end
