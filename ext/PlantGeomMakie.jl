module PlantGeomMakie

using PlantGeom
import PlantGeom: RefMeshColorant, DictRefMeshColorant, DictVertexRefMeshColorant, AttributeColorant, diagram, diagram!, RefMesh
import PlantGeom: material_single_color, get_color_range, get_colormap
import PlantGeom: merge_simple_meshes, get_ref_mesh_name
import PlantGeom: plantviz, plantviz!
import Makie
import Meshes
import Colors: RGBA, Colorant, RGB
# import Observables # For to_value (get an observable value)
import MultiScaleTreeGraph
import MultiScaleTreeGraph: get_attributes, descendants
import ColorSchemes: get, rainbow, colorschemes, ColorScheme
import UUIDs
import Unitful

include("makie_recipes/opf_recipe.jl")
include("makie_recipes/RefMeshes_recipes.jl")
include("makie_recipes/opf/meshes_to_makie.jl")
include("makie_recipes/opf/plot_opf.jl")
include("makie_recipes/opf/scene_mesh.jl")
include("makie_recipes/mtg_tree_recipe.jl")
include("makie_recipes/colorbar.jl")

export colorbar
end