using PlantGeom
using CairoMakie

# read the coffee plant:
file = joinpath(pkgdir(PlantGeom), "test", "files", "coffee.opf")
opf = read_opf(file)

let
    f = Figure(size=(980, 980), backgroundcolor=:transparent)
    ax = Axis3(f[1, 1], titlealign=:left, aspect=:data, elevation=0.0π, backgroundcolor=:transparent)
    # ax = LScene(f[1, 1], show_axis=false)
    plantviz!(ax, opf)
    hidedecorations!(ax)
    hidespines!(ax)
    f
    save("docs/src/logo.png", f)
end

let
    f = Figure(size=(30, 30), backgroundcolor=:transparent)
    ax = Axis3(f[1, 1], titlealign=:left, aspect=:data, elevation=0.0π, backgroundcolor=:transparent)
    # ax = LScene(f[1, 1], show_axis=false)
    plantviz!(ax, opf)
    hidedecorations!(ax)
    hidespines!(ax)
    f
    save("docs/src/favicon.svg", f)
end

include(joinpath(pkgdir(PlantGeom), "docs", "src", "getting_started", "tree_demo_helpers.jl"))
opf_tree = build_demo_tree_with_growth_api()

let
    f = Figure(size=(250, 250), backgroundcolor=:transparent)
    ax = Axis3(f[1, 1], titlealign=:left, aspect=:data, elevation=0.0π, backgroundcolor=:transparent)
    plantviz!(ax, opf_tree)
    hidedecorations!(ax)
    hidespines!(ax)
    f
    save("docs/src/growth_api.png", f)
end

let
    f = Figure(size=(250, 250), backgroundcolor=:transparent)
    ax = Axis3(f[1, 1], titlealign=:left, aspect=:data, elevation=0.0π, backgroundcolor=:transparent)
    plantviz!(ax, opf, color=:Area)
    hidedecorations!(ax)
    hidespines!(ax)
    f
    save("docs/src/visualize.png", f)
end