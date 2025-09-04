# Benchmark merged vs per-node plotting (manual run)
# Usage:
#   julia --project -O3 test/bench-merged-plotting.jl

using PlantGeom
using MultiScaleTreeGraph
using CairoMakie
using Statistics

const N = 3  # repetitions

# file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "coffee.opf")
file = "/Users/rvezy/Documents/dev/VPalm_test/tests/test2/test.opf"
opf = read_opf(file)
plantviz(opf, color=:green)

function bench_per_node(opf)
    ts = Float64[]
    for _ in 1:N
        GC.gc()
        t = @elapsed begin
            fig, ax, p = plantviz(opf; merged=false, color=:slategray3)
            display(fig) # ensure scene build
        end
        push!(ts, t)
    end
    median(ts), ts
end

function bench_merged(opf)
    ts = Float64[]
    for _ in 1:N
        GC.gc()
        # bump to avoid cache effects between repetitions
        bump_scene_version!(opf)
        t = @elapsed begin
            fig, ax, p = plantviz(opf; merged=true, color=:slategray3)
            display(fig)
        end
        push!(ts, t)
    end
    median(ts), ts
end

println("Benchmarking per-node (N=$(N))...")
med_node, ts_node = bench_per_node(opf)
println("per-node times = ", ts_node)
println("per-node median = ", med_node)

println("\nBenchmarking merged (N=$(N))...")
med_merged, ts_merged = bench_merged(opf)
println("merged times = ", ts_merged)
println("merged median = ", med_merged)

println("\nSpeedup (per-node / merged) = ", med_node / med_merged)

