module PlantGeom

using MultiScaleTreeGraph
import Observables # For to_value (get an observable value)
# For 3D (OPF):
import Meshes
import Meshes: Translate, Affine, Rotate, Scale, Vec
import Meshes: viz, viz!
import TransformsBase: parameters, Identity, Transform, →, SequentialTransform
import TransformsBase: isrevertible, isinvertible
import TransformsBase: apply, revert, reapply, inverse
import TransformsBase: parameters
import Rotations: Rotation, RotZ
import Unitful
import Unitful: @u_str
import Tables

# import GeometryBasics
# import PlyIO
import Colors: RGBA, Colorant, RGB
import ColorSchemes: get, rainbow, colorschemes, ColorScheme

# Read OPF:
import EzXML: readxml, root, StreamReader, attributes, expandtree # For reading OPF files
import EzXML: eachelement, nodename, nodecontent, elements
import EzXML: XMLDocument, ElementNode, setroot!, addelement!, hasnodename
import EzXML: prettyprint # to remove
import StaticArrays: SMatrix, SVector
import StaticArrays
import LinearAlgebra: I, UniformScaling, Diagonal # Used for geometry parsing in OPF
import RecipesBase
import Base
import OrderedCollections

# For random name of the color attribute for caching:
import UUIDs

include("structs.jl")
include("equality.jl")
include("helpers.jl")
include("opf/read_opf.jl")
include("opf/reference_meshes.jl")
include("tapering.jl")
include("opf/refmesh_to_mesh.jl")
include("opf/write_opf.jl")
include("ops/read_ops_file.jl")
include("ops/read_ops.jl")
include("ops/write_ops.jl")
include("meshes/summary_coordinates.jl")
include("meshes/transformations.jl")
include("meshes/scene_merge.jl")
include("plots_recipes/plots_recipe.jl")
include("colors/get_color_type.jl")
include("colors/get_mtg_color.jl")
include("colors/colors.jl")
include("opf/mtg_recipe_helpers.jl")
include("opf/diagram.jl")
include("mesh_simplification.jl")
include("deprecated.jl")

# function viz2 end
# function viz2! end

# 3D Plotting (OPF):
export get_ref_meshes
export viz, viz!

export merge_children_geometry!

export diagram, diagram!

# export nvertices, nelements
export read_opf, write_opf
export read_ops_file, read_ops, write_ops
export taper
export refmesh_to_mesh, get_ref_meshes_color
export xmax, ymax, zmax, xmin, ymin, zmin
export transform_mesh!
export Material, Phong
export RefMesh
export (==), names
export get_color

function colorbar end # Extended in PlantGeomMakie extension
export colorbar

export get_transformation_matrix
export bump_scene_version!

# Defining the main functions for PlantViz:
include("plantviz.jl")
export plantviz, plantviz!

# Code that should be moved to PlantGeomMakie:
import Makie
MeshesMakieExt = Base.get_extension(Meshes, :MeshesMakieExt)

include("../ext/makie_recipes/opf_recipe.jl")
include("../ext/makie_recipes/RefMeshes_recipes.jl")
include("../ext/makie_recipes/opf/meshes_to_makie.jl")
include("../ext/makie_recipes/opf/plot_opf.jl")
include("../ext/makie_recipes/opf/scene_mesh.jl")
include("../ext/makie_recipes/mtg_tree_recipe.jl")
include("../ext/makie_recipes/colorbar.jl")

end
