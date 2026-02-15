using BenchmarkTools
using CairoMakie
using Downloads
using MultiScaleTreeGraph
using PlantGeom

# Fixtures
const PKG_ROOT = dirname(dirname(pathof(PlantGeom)))
const TEST_FILES = joinpath(PKG_ROOT, "test", "files")
const OPF_SMALL_FILE = joinpath(TEST_FILES, "simple_plant.opf")
const OPF_MEDIUM_FILE = joinpath(TEST_FILES, "coffee.opf")
const OPS_SCENE_FILE = joinpath(TEST_FILES, "scene.ops")
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

SUITE["OPF plotting"]["default color"] = BenchmarkGroup()
SUITE["OPF plotting"]["default color"]["small file"] = @benchmarkable plantviz_display($opf_small, cache=$cache)
SUITE["OPF plotting"]["default color"]["medium file"] = @benchmarkable plantviz_display($opf_medium, cache=$cache)

SUITE["OPF plotting"]["render png"] = BenchmarkGroup()
SUITE["OPF plotting"]["render png"]["small file"] = @benchmarkable bench_plot_render_png($opf_small, cache=$cache)
