module PlantGeomMakie

using PlantGeom
import PlantGeom: RefMeshColorant, DictRefMeshColorant, DictVertexRefMeshColorant, AttributeColorant, diagram, diagram!
import PlantGeom: viz, viz!
import Makie
import Meshes
import Colors: RGBA, Colorant, RGB
import Observables # For to_value (get an observable value)
import MultiScaleTreeGraph
import MultiScaleTreeGraph: get_attributes
import ColorSchemes: get, rainbow, colorschemes, ColorScheme
import UUIDs
import Unitful

MeshesMakieExt = Base.get_extension(Meshes, :MeshesMakieExt)

if isnothing(MeshesMakieExt)
    println("Couldn't import the MeshesMakieExt extension, please load the Meshes package before loading PlantGeom")
else
    include("makie_recipes/RefMeshes_recipes.jl")
    include("makie_recipes/opf/meshes_to_makie.jl")
    include("makie_recipes/opf/plot_opf.jl")
    include("makie_recipes/opf_recipe.jl")
    include("makie_recipes/mtg_tree_recipe.jl")
    include("makie_recipes/colorbar.jl")
end

export viz, viz!
export colorbar
export diagram, diagram!

end