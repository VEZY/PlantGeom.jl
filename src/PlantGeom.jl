module PlantGeom

using MultiScaleTreeGraph
import MeshViz: viz, viz!, Viz

# For 3D (OPF):
import Meshes
import GeometryBasics
import Makie
import Colors: RGBA, Colorant, RGB
import ColorSchemes: get, rainbow, colorschemes, ColorScheme

# Read OPF:
import EzXML: readxml, root, StreamReader, attributes, expandtree # For reading OPF files
import EzXML: eachelement, nodename, nodecontent, elements
import EzXML: XMLDocument, ElementNode, setroot!, addelement!
import EzXML: prettyprint # to remove
import StaticArrays: SMatrix, SVector
import LinearAlgebra: I, UniformScaling # Used for geometry parsing in OPF
import CoordinateTransformations: Transformation, Translation, LinearMap, ∘, IdentityTransformation
import RecipesBase
import Base

include("structs.jl")
include("equality.jl")
include("helpers.jl")
include("opf/read_opf.jl")
include("opf/reference_meshes.jl")
include("tapering.jl")
include("opf/refmesh_to_mesh.jl")
include("opf/write_opf.jl")
include("colors.jl")
include("makie_recipes/RefMeshes_recipes.jl")
include("makie_recipes/opf_recipe.jl")
include("makie_recipes/mtg_recipe_helpers.jl")
include("makie_recipes/mtg_tree_recipe.jl")
include("meshes/summary_coordinates.jl")
include("meshes/transformations.jl")
include("ref_meshes/cylinder_refmesh.jl")
include("plots_recipes/plots_recipe.jl")
include("makie_recipes/colorbar.jl")

# 3D Plotting (OPF):
export get_ref_meshes
export viz, viz!
export nvertices, nelements
export read_opf, write_opf
export taper
export refmesh_to_mesh, get_ref_meshes_color
export xmax, ymax, zmax, xmin, ymin, zmin
export refmesh_to_mesh!
export transform_mesh!
export Material, Phong
export RefMesh, RefMeshes
export (==), names
export Diagram, diagram, diagram!
export cylinder
export colorbar

end
