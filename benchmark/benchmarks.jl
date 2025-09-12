using BenchmarkTools
using PlantGeom
using MultiScaleTreeGraph
using CairoMakie
using Downloads

# auxiliary variables
file_small = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
file_medium = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf")
file_large = Downloads.download("https://api.figshare.com/v2/file/download/57762715")

# initialize benchmark suite
const SUITE = BenchmarkGroup()

const cache = false # Disable caching for benchmarking

# ---------
# IO
# ---------

SUITE["OPF read"] = BenchmarkGroup()
SUITE["OPF read"]["small file"] = @benchmarkable read_opf($file_small)
SUITE["OPF read"]["medium file"] = @benchmarkable read_opf($file_medium)
SUITE["OPF read"]["large file"] = @benchmarkable read_opf($file_large)

# ---------
# Plotting
# ---------
plantviz_display(opf; kwargs...) = display(plantviz(opf; kwargs...))

SUITE["OPF plotting"] = BenchmarkGroup()

opf_small = read_opf(file_small)
opf_medium = read_opf(file_medium)
opf_large = read_opf(file_large)

# @benchmark plantviz(opf_medium, cache=false)
# BenchmarkTools.Trial: 25 samples with 1 evaluation per sample.
#  Range (min … max):  163.945 ms … 474.082 ms  ┊ GC (min … max):  0.00% … 65.93%
#  Time  (median):     183.381 ms               ┊ GC (median):    11.58%
#  Time  (mean ± σ):   206.254 ms ±  78.629 ms  ┊ GC (mean ± σ):  20.88% ± 16.36%
#   ▄  █                                                           
#   █▁▄██▆▆█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▄▁▁▄ ▁
#   164 ms           Histogram: frequency by time          474 ms <
#  Memory estimate: 269.29 MiB, allocs estimate: 5625477

# Reference mesh:
SUITE["OPF plotting"]["single color"]["small file"] = @benchmarkable plantviz_display($opf_small, cache=$cache)
SUITE["OPF plotting"]["single color"]["medium file"] = @benchmarkable plantviz_display($opf_medium, cache=$cache)
SUITE["OPF plotting"]["single color"]["large file"] = @benchmarkable plantviz_display($opf_large, cache=$cache)

# Single color:
color = :green
SUITE["OPF plotting"]["single color"]["small file"] = @benchmarkable plantviz_display($opf_small, color=$color, cache=$cache)
SUITE["OPF plotting"]["single color"]["medium file"] = @benchmarkable plantviz_display($opf_medium, color=$color, cache=$cache)
SUITE["OPF plotting"]["single color"]["large file"] = @benchmarkable plantviz_display($opf_large, color=$color, cache=$cache)

# Attribute color:
color = :mesh_index
global i = Ref(0)
transform!(opf_small, :geometry => (x -> i[] += 1) => color, ignore_nothing=true)
transform!(opf_medium, :geometry => (x -> i[] += 1) => color, ignore_nothing=true)
transform!(opf_large, :geometry => (x -> i[] += 1) => color, ignore_nothing=true)
SUITE["OPF plotting"]["attribute color"]["small file"] = @benchmarkable plantviz_display($opf_small, color=$color, cache=$cache)
SUITE["OPF plotting"]["attribute color"]["medium file"] = @benchmarkable plantviz_display($opf_medium, color=$color, cache=$cache)
SUITE["OPF plotting"]["attribute color"]["large file"] = @benchmarkable plantviz_display($opf_large, color=$color, cache=$cache)