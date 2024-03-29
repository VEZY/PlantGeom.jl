module PlantGeom

using MultiScaleTreeGraph
import Observables # For to_value (get an observable value)
# For 3D (OPF):
import Meshes
import Meshes: viz, viz!

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
import LinearAlgebra: I, UniformScaling # Used for geometry parsing in OPF
import CoordinateTransformations: Transformation, Translation, LinearMap, ∘, IdentityTransformation
import RecipesBase
import Base

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
include("meshes/summary_coordinates.jl")
include("meshes/transformations.jl")
include("ref_meshes/cylinder_refmesh.jl")
include("plots_recipes/plots_recipe.jl")
include("colors/get_color_type.jl")
include("colors/colors.jl")
include("colors/get_mtg_color.jl")
include("opf/mtg_recipe_helpers.jl")

# function viz2 end
# function viz2! end

# 3D Plotting (OPF):
export get_ref_meshes
export viz, viz!
# export nvertices, nelements
export read_opf, write_opf
export taper
export refmesh_to_mesh, get_ref_meshes_color
export xmax, ymax, zmax, xmin, ymin, zmin
export refmesh_to_mesh!
export transform_mesh!
export Material, Phong
export RefMesh, RefMeshes
export (==), names
export get_color, get_colormap

function colorbar end # Extended in PlantGeomMakie extension
export colorbar

end
