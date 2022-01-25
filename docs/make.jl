using PlantGeom
using Documenter

DocMeta.setdocmeta!(PlantGeom, :DocTestSetup, :(using PlantGeom; using MultiScaleTreeGraph); recursive = true)

makedocs(;
    modules = [PlantGeom],
    authors = "remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo = "https://github.com/VEZY/PlantGeom.jl/blob/{commit}{path}#{line}",
    sitename = "PlantGeom.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://VEZY.github.io/PlantGeom.jl",
        assets = String[]
    ),
    pages = [
        "Home" => "index.md",
        "Recipes" => [
            "Makie.jl" => "makie_recipes.md",
            "Plots.jl" => "plots_recipes.md",
        ],
        "API" => "API.md"
    ]
)

deploydocs(;
    repo = "github.com/VEZY/PlantGeom.jl",
    devbranch = "main"
)
