using CairoMakie
using Meshes
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
        size_threshold=2_000_000,
    ),
    pages=[
        "Home" => "index.md",
        "2D diagrams" => [
            "Makie.jl" => "plot_diagram/makie_diagram.md",
            "Plots.jl" => "plot_diagram/plots_diagram.md",
        ],
        "3D recipes" => "makie_3d.md",
        "Geometry" => [
            "Geometry" => "geometry/geometry.md",
            "RefMesh" => "geometry/refmesh.md",
            "Mesh" => "geometry/mesh.md",
            "Merging meshes" => "geometry/merging_geometry.md",
        ],
        "API" => "API.md"
    ]
)

deploydocs(;
    repo="github.com/VEZY/PlantGeom.jl.git",
    devbranch="main"
)
