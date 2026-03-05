using CairoMakie
using PlantGeom
using Statistics
using Documenter

DocMeta.setdocmeta!(PlantGeom, :DocTestSetup, :(using PlantGeom; using MultiScaleTreeGraph; using Bonito; using Statistics); recursive=true)

makedocs(;
    modules=[PlantGeom],
    authors="Rémi Vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("VEZY", "PlantGeom.jl"),
    sitename="PlantGeom.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VEZY.github.io/PlantGeom.jl",
        edit_link="main",
        assets=String[],
        example_size_threshold=500000,
        size_threshold=2_500_000,
        size_threshold_warn=2_500_000,
        collapselevel=3,
    ),
    pages=[
        "Home" => "index.md",
        "IO and File Formats" => "io.md",
        "3D Plots" => "makie_3d.md",
        "Geometry Concepts" => [
            "Reference Meshes" => "geometry/refmesh.md",
            "Procedural / Extrusion Geometry" => "geometry/procedural_geometry.md",
            "Growth API" => "geometry/growth_api.md",
            "Merging Meshes" => "geometry/merging_geometry.md",
        ],
        "Building a 3D plant" => "geometry/building_plant_models.md",
        "AMAP-Style reconstructions" => [
            "Quickstart" => "geometry/amap_quickstart.md",
            "Reconstruction Decision Guide" => "geometry/amap_reconstruction_decision_guide.md",
            "Conventions Reference" => "geometry/amap_conventions_reference.md",
            "AMAPStudio Parity Matrix" => "geometry/amap_parity_matrix.md",
        ],
        "Plotting the graph" => [
            "Makie.jl" => "plot_diagram/makie_diagram.md",
            "Plots.jl" => "plot_diagram/plots_diagram.md",
        ],
        "For developpers" => "architecture.md",
        "API" => "API.md"
    ]
)

deploydocs(;
    repo="github.com/VEZY/PlantGeom.jl.git",
    devbranch="main"
)
