using CairoMakie
using Meshes
using PlantGeom
using Documenter

DocMeta.setdocmeta!(PlantGeom, :DocTestSetup, :(using PlantGeom; using MultiScaleTreeGraph; using JSServe); recursive=true)

makedocs(;
    modules=[PlantGeom],
    authors="Rémi Vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("VEZY", "PlantGeom.jl"),
    sitename="PlantGeom.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VEZY.github.io/PlantGeom.jl",
        edit_link="main",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
        "Plot recipes" => [
            "MTG diagrams" => [
                "Makie.jl" => "plot_diagram/makie_diagram.md",
                "Plots.jl" => "plot_diagram/plots_diagram.md",
            ],
            "3D Makie recipes" => "makie_3d.md"
        ],
        "API" => "API.md"
    ]
)

deploydocs(;
    repo="github.com/VEZY/PlantGeom.jl.git",
    devbranch="main"
)
