using CairoMakie
using PlantGeom
using Statistics
using Documenter
using DocumenterVitepress
using PlantSimEngine

# Run this with hot-reload from docs: `npm run docs:dev`
# Kill the server: `pkill -f vitepress`
DocMeta.setdocmeta!(PlantGeom, :DocTestSetup, :(using PlantGeom; using MultiScaleTreeGraph; using Bonito; using Statistics; using PlantSimEngine); recursive=true)

makedocs(;
    modules=[PlantGeom],
    authors="Rémi Vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("VEZY", "PlantGeom.jl"),
    sitename="PlantGeom.jl",
    format=DocumenterVitepress.MarkdownVitepress(;
        # prettyurls=get(ENV, "CI", "false") == "true",
        repo="github.com/VEZY/PlantGeom.jl",
        devbranch="main",
        devurl="dev",
        # assets=String[],
        # example_size_threshold=500000,
        # size_threshold=2_500_000,
        # size_threshold_warn=2_500_000,
        # collapselevel=3,
    ),
    pages=[
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => [
                "Quickstart: Grow a Plant" => "getting_started/quickstart_grow.md",
                "Quickstart: 3D Plot" => "getting_started/showcase.md",
            ],
            "Plotting" => [
                "3D Plotting with Makie.jl" => "getting_started/makie_3d.md",
                "Diagram with Makie.jl" => "plot_diagram/makie_diagram.md",
                "Diagram with Plots.jl" => "plot_diagram/plots_diagram.md",
            ],
            "Build & Simulate Plants" => [
                "Workflow Tutorial" => "build_and_simulate_3d_plants/choose_a_workflow.md",
                "Growth API" => "build_and_simulate_3d_plants/growth_api.md",
                "Assemble a Mixed Scene" => "build_and_simulate_3d_plants/scene_assembly.md",
                "Growth API with PlantSimEngine" => "build_and_simulate_3d_plants/growth_api_plantsimengine.md",
                "Reconstructing an MTG" => [
                    "Tutorial" => "build_and_simulate_3d_plants/reconstruct_from_mtg/amap_quickstart.md",
                    "Conventions Reference" => "build_and_simulate_3d_plants/reconstruct_from_mtg/amap_conventions_reference.md",
                    "Explicit Coordinate Modes" => "build_and_simulate_3d_plants/reconstruct_from_mtg/amap_reconstruction_decision_guide.md",
                ],
            ],
            "Reference meshes" => [
                "Reference Meshes" => "geometry/refmesh.md",
                "Procedural / Extrusion Geometry" => "geometry/procedural_geometry.md",
                "Prototype Mesh API" => "geometry/prototype_mesh_api.md",
                "Merging Meshes" => "geometry/merging_geometry.md",
            ],
            "IO and File Formats" => "io.md",
        ],
        "API" => "API.md",
        "For developers" => "architecture.md",
    ]
)

DocumenterVitepress.deploydocs(;
    repo="github.com/VEZY/PlantGeom.jl",
    devbranch="main",
    branch="gh-pages",
    push_preview=true,
)
