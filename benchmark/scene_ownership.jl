using BenchmarkTools
using GeometryBasics
using MultiScaleTreeGraph
using PlantGeom

function ownership_one_face_organ_scene(n_organs::Int=1000)
    mesh = GeometryBasics.Mesh(
        Point{3,Float64}[
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            Point(0.0, 1.0, 0.0),
        ],
        GeometryBasics.TriangleFace{Int}[
            GeometryBasics.TriangleFace{Int}(1, 2, 3),
        ],
    )
    shared_ref = RefMesh("one-face-organ", mesh)
    plant = Node(NodeMTG(:/, :Plant, 1, 1), Dict{Symbol,Any}())
    for i in 1:n_organs
        Node(
            i + 1,
            plant,
            NodeMTG(:+, :Leaf, i, 2),
            Dict{Symbol,Any}(
                :source_topology_id => i + 1,
                :geometry => PlantGeom.Geometry(ref_mesh=shared_ref),
            ),
        )
    end
    return plant
end

function ownership_make_scene_default(plant)
    make_scene(domain=(0.0, 0.0, 2.0, 2.0)) do builder
        add_plant!(builder, plant; group="plants", id=1)
    end
end

function ownership_make_scene_minimal(plant)
    make_scene(
        domain=(0.0, 0.0, 2.0, 2.0),
        compute_area=false,
        compute_barycenter=false,
        source_topology_id=false,
    ) do builder
        add_plant!(builder, plant; group="plants", id=1)
    end
end

const OWNERSHIP_ONE_FACE_TEMPLATE = ownership_one_face_organ_scene()
const OWNERSHIP_ONE_FACE_PREPARED_DEFAULT =
    prepare_scene(deepcopy(OWNERSHIP_ONE_FACE_TEMPLATE))

# The main baseline cannot infer SceneNodeData{T} when every typed summary is
# `nothing`. Keep these cases on revisions with the explicit source-owner API;
# Airspeed reports their unavailable baseline values as missing.
if isdefined(PlantGeom, :SourceOwnerKey)
    const OWNERSHIP_ONE_FACE_PREPARED_MINIMAL = prepare_scene(
        deepcopy(OWNERSHIP_ONE_FACE_TEMPLATE);
        compute_area=false,
        compute_barycenter=false,
        source_topology_id=false,
    )
end

const SCENE_OWNERSHIP_SUITE = BenchmarkGroup()
SCENE_OWNERSHIP_SUITE["prepare defaults, raw"] = @benchmarkable prepare_scene(tree) setup = (
    tree = deepcopy($OWNERSHIP_ONE_FACE_TEMPLATE)
) evals = 1
SCENE_OWNERSHIP_SUITE["prepare defaults, refresh"] =
    @benchmarkable prepare_scene($OWNERSHIP_ONE_FACE_PREPARED_DEFAULT.mtg) evals = 1
SCENE_OWNERSHIP_SUITE["make_scene defaults"] =
    @benchmarkable ownership_make_scene_default($OWNERSHIP_ONE_FACE_TEMPLATE) evals = 1

if isdefined(PlantGeom, :SourceOwnerKey)
    SCENE_OWNERSHIP_SUITE["prepare summaries disabled, raw"] = @benchmarkable prepare_scene(
        tree;
        compute_area=false,
        compute_barycenter=false,
        source_topology_id=false,
    ) setup = (tree = deepcopy($OWNERSHIP_ONE_FACE_TEMPLATE)) evals = 1
    SCENE_OWNERSHIP_SUITE["prepare summaries disabled, refresh"] = @benchmarkable prepare_scene(
        $OWNERSHIP_ONE_FACE_PREPARED_MINIMAL.mtg;
        compute_area=false,
        compute_barycenter=false,
        source_topology_id=false,
    ) evals = 1
    SCENE_OWNERSHIP_SUITE["make_scene summaries disabled"] =
        @benchmarkable ownership_make_scene_minimal($OWNERSHIP_ONE_FACE_TEMPLATE) evals = 1
end

if abspath(PROGRAM_FILE) == @__FILE__
    BenchmarkTools.tune!(SCENE_OWNERSHIP_SUITE)
    display(BenchmarkTools.run(SCENE_OWNERSHIP_SUITE; verbose=true))
end
