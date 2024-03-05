module PlantGeomMakie

using PlantGeom
import Makie
import Meshes
import Colors: RGBA, Colorant, RGB
import Observables # For to_value (get an observable value)
import MultiScaleTreeGraph
import MultiScaleTreeGraph: get_attributes
import ColorSchemes: get, rainbow, colorschemes, ColorScheme
import UUIDs

MeshesMakieExt = Base.get_extension(Meshes, :MeshesMakieExt)

include("makie_recipes/colors/get_color_type.jl")
include("makie_recipes/colors/get_mtg_color.jl")
include("makie_recipes/RefMeshes_recipes.jl")
include("makie_recipes/opf/plot_opf.jl")
include("makie_recipes/opf_recipe.jl")
include("makie_recipes/mtg_recipe_helpers.jl")
include("makie_recipes/mtg_tree_recipe.jl")
include("makie_recipes/colors/colorbar.jl")

export viz, viz!
export colorbar

end