using BenchmarkTools
using PlantGeom
using MultiScaleTreeGraph
using CairoMakie

# auxiliary variables
file_small = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
file_medium = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf")
file_large = "/Users/rvezy/Documents/dev/VPalm_test/tests/test2/test.opf"

# initialize benchmark suite
const SUITE = BenchmarkGroup()

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

SUITE["OPF plotting"] = BenchmarkGroup()

opf_small = read_opf(file_small)
opf_medium = read_opf(file_medium)
opf_large = read_opf(file_large)

# Reference mesh:
SUITE["OPF plotting"]["single color"]["small file"] = @benchmarkable plantviz($opf_small)
SUITE["OPF plotting"]["single color"]["medium file"] = @benchmarkable plantviz($opf_medium)
SUITE["OPF plotting"]["single color"]["large file"] = @benchmarkable plantviz($opf_large)

# Single color:
color = :green
SUITE["OPF plotting"]["single color"]["small file"] = @benchmarkable plantviz($opf_small, color=$color)
SUITE["OPF plotting"]["single color"]["medium file"] = @benchmarkable plantviz($opf_medium, color=$color)
SUITE["OPF plotting"]["single color"]["large file"] = @benchmarkable plantviz($opf_large, color=$color)

# Attribute color:
color = :mesh_index
global i = Ref(0)
transform!(opf_small, :geometry => (x -> i[] += 1) => color, ignore_nothing=true)
transform!(opf_medium, :geometry => (x -> i[] += 1) => color, ignore_nothing=true)
transform!(opf_large, :geometry => (x -> i[] += 1) => color, ignore_nothing=true)
SUITE["OPF plotting"]["attribute color"]["small file"] = @benchmarkable plantviz($opf_small, color=$color)
SUITE["OPF plotting"]["attribute color"]["medium file"] = @benchmarkable plantviz($opf_medium, color=$color)
SUITE["OPF plotting"]["attribute color"]["large file"] = @benchmarkable plantviz($opf_large, color=$color)

