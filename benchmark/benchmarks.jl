using BenchmarkTools
using CairoMakie
using Downloads
using GeometryBasics
using MultiScaleTreeGraph
using PlantGeom

# Fixtures
const PKG_ROOT = dirname(dirname(pathof(PlantGeom)))
const TEST_FILES = joinpath(PKG_ROOT, "test", "files")
const OPF_SMALL_FILE = joinpath(TEST_FILES, "simple_plant.opf")
const OPF_MEDIUM_FILE = joinpath(TEST_FILES, "coffee.opf")
const OPS_SCENE_FILE = joinpath(TEST_FILES, "scene.ops")
const MTG_STANDARD_FILE = joinpath(TEST_FILES, "reconstruction_standard.mtg")
const OPF_LARGE_URL = "https://api.figshare.com/v2/file/download/57762715"

function get_large_fixture(url)
    try
        return Downloads.download(url)
    catch
        return nothing
    end
end

const OPF_LARGE_FILE = get_large_fixture(OPF_LARGE_URL)

# initialize benchmark suite
const SUITE = BenchmarkGroup()
const cache = false # Disable caching for benchmarking

# ---------
# AMAP reconstruction fixtures
# ---------

function benchmark_ref_meshes()
    tri = GeometryBasics.TriangleFace{Int}
    stem_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            0.5,
        ),
    )
    leaf_mesh = GeometryBasics.Mesh(
        [
            Point(0.0, -0.1, 0.0),
            Point(0.0, 0.1, 0.0),
            Point(1.0, 0.0, 0.0),
        ],
        [tri(1, 2, 3)],
    )

    Dict(
        "Internode" => RefMesh("Stem", stem_mesh),
        "Leaf" => RefMesh("Leaf", leaf_mesh),
    )
end

const AMAP_REF_MESHES = benchmark_ref_meshes()
const AMAP_CONV = default_amap_geometry_convention()
const AMAP_DEFAULT_OPTS = default_amap_reconstruction_options()

function bench_reconstruct!(mtg; amap_options=AMAP_DEFAULT_OPTS)
    reconstruct_geometry_from_attributes!(
        mtg,
        AMAP_REF_MESHES;
        convention=AMAP_CONV,
        amap_options=amap_options,
        root_align=false,
    )
    return nothing
end

function build_scratch_mtg(; n_segments::Int=40)
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    internode = Node(mtg, NodeMTG(:/, :Internode, 1, 2))

    for i in 1:n_segments
        internode[:Length] = 0.22 * (0.985^(i - 1))
        internode[:Width] = max(0.032 - 0.00035 * (i - 1), 0.015)
        internode[:Thickness] = internode[:Width]
        internode[:YInsertionAngle] = 12.0 + 2.5 * sin(i / 3)
        internode[:DeviationAngle] = 5.0 + 0.7 * cos(i / 4)

        if i % 2 == 0
            leaf = Node(internode, NodeMTG(:+, :Leaf, i, 2))
            leaf[:Length] = 0.18 + 0.02 * cos(i / 5)
            leaf[:Width] = 0.08 + 0.01 * sin(i / 7)
            leaf[:Thickness] = 0.002
            leaf[:XInsertionAngle] = 60.0 + 30.0 * ((i ÷ 2) % 2)
            leaf[:YInsertionAngle] = 40.0 + 8.0 * sin(i / 3)
            leaf[:Offset] = 0.8 * internode[:Length]
        end

        if i < n_segments
            internode = Node(internode, NodeMTG(:<, :Internode, i + 1, 2))
        end
    end

    return mtg
end

function build_stiffness_scene(; n_components::Int=18)
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    stem = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
    stem[:Length] = 28.0
    stem[:Width] = 0.12
    stem[:Thickness] = 0.12
    stem[:Stifness] = -6.0e4
    stem[:StifnessTapering] = 0.55
    stem[:StiffnessApply] = true

    for i in 1:n_components
        c = Node(stem, NodeMTG(:/, :Leaf, i, 3))
        c[:Length] = 0.22
        c[:Width] = 0.055
        c[:Thickness] = 0.01
    end

    return mtg
end

function build_geometrical_constraint_scene(mode::Symbol)
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    internode = Node(mtg, NodeMTG(:/, :Internode, 1, 2))

    shared_constraint = Dict{Symbol,Any}(
        :type => :cone_cylinder,
        :primary_angle => 14.0,
        :secondary_angle => 14.0,
        :cone_length => 0.35,
        :origin => (0.0, 0.0, 0.0),
        :axis => (1.0, 0.0, 0.0),
    )

    for i in 1:9
        internode[:Length] = 0.15
        internode[:Width] = max(0.08 - 0.004 * (i - 1), 0.04)
        internode[:Thickness] = internode[:Width]
        internode[:YInsertionAngle] = 19.0
        internode[:DeviationAngle] = 8.0
        if mode === :constrained
            internode[:GeometricalConstraint] = shared_constraint
        end

        if i < 9
            internode = Node(internode, NodeMTG(:<, :Internode, i + 1, 2))
        end
    end

    return mtg
end

function build_explicit_coordinate_scene()
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    i1 = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
    i2 = Node(i1, NodeMTG(:<, :Internode, 2, 2))
    i3 = Node(i2, NodeMTG(:<, :Internode, 3, 2))

    for n in (i1, i2, i3)
        n[:Length] = 0.45
        n[:Width] = 0.09
        n[:Thickness] = 0.09
    end

    i1[:XX] = 0.0
    i1[:YY] = 0.0
    i1[:ZZ] = 0.0
    i1[:EndX] = 0.55
    i1[:EndY] = 0.00
    i1[:EndZ] = 0.00

    i2[:XX] = 0.86
    i2[:YY] = 0.28
    i2[:ZZ] = 0.10
    i2[:YInsertionAngle] = -30.0
    i2[:Azimuth] = 25.0

    i3[:YInsertionAngle] = 35.0
    i3[:Azimuth] = -30.0

    return mtg
end

# ---------
# IO
# ---------

SUITE["OPF read"] = BenchmarkGroup()
SUITE["OPF read"]["small file"] = @benchmarkable read_opf($OPF_SMALL_FILE)
SUITE["OPF read"]["medium file"] = @benchmarkable read_opf($OPF_MEDIUM_FILE)
if !isnothing(OPF_LARGE_FILE)
    SUITE["OPF read"]["large file"] = @benchmarkable read_opf($OPF_LARGE_FILE)
end

# ---------
# Plotting
# ---------
plantviz_display(opf; kwargs...) = (display(plantviz(opf; kwargs...)); nothing)

SUITE["OPF plotting"] = BenchmarkGroup()
SUITE["OPF plotting"]["single color"] = BenchmarkGroup()
SUITE["OPF plotting"]["attribute color"] = BenchmarkGroup()

opf_small = read_opf(OPF_SMALL_FILE)
opf_medium = read_opf(OPF_MEDIUM_FILE)
opf_small_attr = deepcopy(opf_small)
opf_medium_attr = deepcopy(opf_medium)

color = :green
SUITE["OPF plotting"]["single color"]["small file"] = @benchmarkable plantviz_display($opf_small, color=$color, cache=$cache)
SUITE["OPF plotting"]["single color"]["medium file"] = @benchmarkable plantviz_display($opf_medium, color=$color, cache=$cache)
if !isnothing(OPF_LARGE_FILE)
    opf_large = read_opf(OPF_LARGE_FILE)
    SUITE["OPF plotting"]["single color"]["large file"] = @benchmarkable plantviz_display($opf_large, color=$color, cache=$cache)
end

color_attr = :mesh_index
global i = Ref(0)
transform!(opf_small_attr, :geometry => (_ -> i[] += 1) => color_attr, ignore_nothing=true)
transform!(opf_medium_attr, :geometry => (_ -> i[] += 1) => color_attr, ignore_nothing=true)
SUITE["OPF plotting"]["attribute color"]["small file"] = @benchmarkable plantviz_display($opf_small_attr, color=$color_attr, cache=$cache)
SUITE["OPF plotting"]["attribute color"]["medium file"] = @benchmarkable plantviz_display($opf_medium_attr, color=$color_attr, cache=$cache)
if !isnothing(OPF_LARGE_FILE)
    opf_large_attr = read_opf(OPF_LARGE_FILE)
    transform!(opf_large_attr, :geometry => (_ -> i[] += 1) => color_attr, ignore_nothing=true)
    SUITE["OPF plotting"]["attribute color"]["large file"] = @benchmarkable plantviz_display($opf_large_attr, color=$color_attr, cache=$cache)
end

function bench_write_opf(mtg)
    output = tempname() * ".opf"
    try
        write_opf(output, mtg)
    finally
        isfile(output) && rm(output)
    end
    return nothing
end

function bench_write_ops(scene_dimensions, object_table)
    output = tempname() * ".ops"
    try
        write_ops(output, scene_dimensions, object_table)
    finally
        isfile(output) && rm(output)
    end
    return nothing
end

function bench_plot_render_png(opf; kwargs...)
    fig, _, _ = plantviz(opf; kwargs...)
    io = IOBuffer()
    show(io, MIME("image/png"), fig)
    return nothing
end

ops_scene = read_ops_file(OPS_SCENE_FILE)

SUITE["OPF write"] = BenchmarkGroup()
SUITE["OPF write"]["small file"] = @benchmarkable bench_write_opf(tree) setup = (tree = read_opf($OPF_SMALL_FILE))
SUITE["OPF write"]["medium file"] = @benchmarkable bench_write_opf(tree) setup = (tree = read_opf($OPF_MEDIUM_FILE))

SUITE["OPS IO"] = BenchmarkGroup()
SUITE["OPS IO"]["read scene"] = @benchmarkable read_ops($OPS_SCENE_FILE)
SUITE["OPS IO"]["write scene"] = @benchmarkable bench_write_ops($ops_scene.scene_dimensions, $ops_scene.object_table)

SUITE["AMAP reconstruction"] = BenchmarkGroup()
SUITE["AMAP reconstruction"]["from scratch"] = BenchmarkGroup()
SUITE["AMAP reconstruction"]["from MTG file"] = BenchmarkGroup()
SUITE["AMAP reconstruction"]["AMAP features"] = BenchmarkGroup()

SUITE["AMAP reconstruction"]["from scratch"]["build + reconstruct"] =
    @benchmarkable begin
        mtg = build_scratch_mtg(n_segments=40)
        bench_reconstruct!(mtg)
    end evals = 1

SUITE["AMAP reconstruction"]["from scratch"]["reconstruct prebuilt"] =
    @benchmarkable bench_reconstruct!(mtg) setup = (mtg = build_scratch_mtg(n_segments=40)) evals = 1

SUITE["AMAP reconstruction"]["from MTG file"]["read + reconstruct (reconstruction_standard.mtg)"] =
    @benchmarkable begin
        mtg = read_mtg($MTG_STANDARD_FILE)
        bench_reconstruct!(mtg)
    end evals = 1

SUITE["AMAP reconstruction"]["from MTG file"]["reconstruct preloaded (reconstruction_standard.mtg)"] =
    @benchmarkable bench_reconstruct!(mtg) setup = (mtg = read_mtg($MTG_STANDARD_FILE)) evals = 1

SUITE["AMAP reconstruction"]["AMAP features"]["stiffness propagation"] =
    @benchmarkable bench_reconstruct!(mtg) setup = (mtg = build_stiffness_scene(n_components=18)) evals = 1

SUITE["AMAP reconstruction"]["AMAP features"]["GeometricalConstraint (free axis)"] =
    @benchmarkable bench_reconstruct!(mtg) setup = (mtg = build_geometrical_constraint_scene(:free)) evals = 1

SUITE["AMAP reconstruction"]["AMAP features"]["GeometricalConstraint (cone-cylinder)"] =
    @benchmarkable bench_reconstruct!(mtg) setup = (mtg = build_geometrical_constraint_scene(:constrained)) evals = 1

SUITE["AMAP reconstruction"]["AMAP features"]["explicit_coordinate_mode (:topology_default)"] =
    @benchmarkable bench_reconstruct!(mtg; amap_options=opts) setup = (
        mtg = build_explicit_coordinate_scene();
        opts = AmapReconstructionOptions(explicit_coordinate_mode=:topology_default)
    ) evals = 1

SUITE["AMAP reconstruction"]["AMAP features"]["explicit_coordinate_mode (:explicit_rewire_previous)"] =
    @benchmarkable bench_reconstruct!(mtg; amap_options=opts) setup = (
        mtg = build_explicit_coordinate_scene();
        opts = AmapReconstructionOptions(explicit_coordinate_mode=:explicit_rewire_previous)
    ) evals = 1

SUITE["AMAP reconstruction"]["AMAP features"]["explicit_coordinate_mode (:explicit_start_end_required)"] =
    @benchmarkable bench_reconstruct!(mtg; amap_options=opts) setup = (
        mtg = build_explicit_coordinate_scene();
        opts = AmapReconstructionOptions(explicit_coordinate_mode=:explicit_start_end_required)
    ) evals = 1

SUITE["OPF plotting"]["default color"] = BenchmarkGroup()
SUITE["OPF plotting"]["default color"]["small file"] = @benchmarkable plantviz_display($opf_small, cache=$cache)
SUITE["OPF plotting"]["default color"]["medium file"] = @benchmarkable plantviz_display($opf_medium, cache=$cache)

SUITE["OPF plotting"]["render png"] = BenchmarkGroup()
SUITE["OPF plotting"]["render png"]["small file"] = @benchmarkable bench_plot_render_png($opf_small, cache=$cache)
