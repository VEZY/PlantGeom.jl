using PlantGeom
using Documenter

DocMeta.setdocmeta!(PlantGeom, :DocTestSetup, :(using PlantGeom); recursive=true)

makedocs(;
    modules=[PlantGeom],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo="https://github.com/VEZY/PlantGeom.jl/blob/{commit}{path}#{line}",
    sitename="PlantGeom.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VEZY.github.io/PlantGeom.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/VEZY/PlantGeom.jl",
    devbranch="main",
)
