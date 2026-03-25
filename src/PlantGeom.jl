module PlantGeom

using MultiScaleTreeGraph

# For 3D (OPF):
import CoordinateTransformations
import CoordinateTransformations: Transformation, IdentityTransformation, Translation, LinearMap, AffineMap, ComposedTransformation
import CoordinateTransformations: compose, ∘, recenter
import GeometryBasics
import Rotations: Rotation, RotZ, AngleAxis, RotMatrix
import Unitful
import Unitful: @u_str
import Tables

# import GeometryBasics
# import PlyIO
import Colors: RGBA, Colorant, RGB
import ColorSchemes: get, rainbow, colorschemes, ColorScheme
import FixedPointNumbers: N0f8

# Read OPF:
import EzXML: readxml, root, StreamReader, attributes, expandtree # For reading OPF files
import EzXML: eachelement, nodename, nodecontent, elements
import EzXML: XMLDocument, ElementNode, setroot!, addelement!, hasnodename
import EzXML: prettyprint # to remove
import StaticArrays: SMatrix, SVector
import StaticArrays
import LinearAlgebra: I, UniformScaling, Diagonal, norm, cross, dot # Used for geometry parsing in OPF
import RecipesBase
import Base
import OrderedCollections

# For random name of the color attribute for caching:
import UUIDs

include("geometry_backend.jl")
include("structs.jl")
include("geometry/types.jl")
include("geometry/pointmaps.jl")
include("geometry/materialize.jl")
include("geometry/metadata.jl")
include("reconstruction/amap_reconstruction.jl")
include("reconstruction/prototypes.jl")
include("reconstruction/conventions.jl")
include("growth/growth_api.jl")
include("equality.jl")
include("helpers.jl")
include("opf/read_opf.jl")
include("opf/reference_meshes.jl")
include("tapering.jl")
include("opf/write_opf.jl")
include("gwa/read_gwa.jl")
include("gwa/write_gwa.jl")
include("ops/read_ops_file.jl")
include("ops/scene_helpers.jl")
include("ops/read_ops.jl")
include("ops/write_ops.jl")
include("meshes/summary_coordinates.jl")
include("meshes/transformations.jl")
include("meshes/extrusion.jl")
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

export merge_children_geometry!

export diagram, diagram!

# export nvertices, nelements
export read_opf, read_gwa, write_opf, write_gwa
export read_ops_file, read_ops, write_ops, write_ops_file
export scene_object_transformation, place_in_scene!
export taper
export refmesh_to_mesh, get_ref_meshes_color
export xmax, ymax, zmax, xmin, ymin, zmin
export transform_mesh!
export extrude_profile_mesh, extrude_profile_refmesh, extrude_tube_mesh
export ExtrudedTubeGeometry
export PointMappedGeometry
export RationalBezierCurve, LaminaMidribMap, lamina_midrib, lamina_mesh, lamina_refmesh
export LaminaTwistRollMap, LaminaAnticlasticWaveMap, ComposedPointMap, compose_point_maps
export PointMapFrame, with_point_map_frame
export final_angle, local_flexion, calculate_segment_angles, update_segment_angles!, BiomechanicalBendingTransform
export extrusion_make_path, extrusion_make_spline, extrusion_make_interpolation, extrusion_make_curve
export lathe_gen_mesh, lathe_gen_refmesh, lathe_mesh, lathe_refmesh
export circle_section_profile, leaflet_midrib_profile
export Material, Phong
export RefMesh
export (==), names
export get_color
export nvertices, nelements
export GeometryConvention
export default_geometry_convention
export default_amap_geometry_convention
export AmapReconstructionOptions
export default_amap_reconstruction_options
export AbstractMeshPrototype, AbstractParametricPrototype
export RefMeshPrototype, PointMapPrototype, ExtrusionPrototype, RawMeshPrototype
export available_parameters, effective_parameters
export transformation_from_attributes
export geometry_from_attributes
export reconstruct_geometry_from_attributes!
export set_geometry_from_attributes!
export emit_internode!, emit_leaf!, emit_phytomer!
export grow_length!, grow_width!, set_growth_attributes!, rebuild_geometry!

function colorbar end # Extended in PlantGeomMakie extension
export colorbar

function to_meshes end # Extended in PlantGeomMeshesInterop extension
function to_geometrybasics end # Extended in PlantGeomMeshesInterop extension
export to_meshes, to_geometrybasics

export get_transformation_matrix
export bump_scene_version!

# Defining the main functions for PlantViz:
include("plantviz.jl")
export plantviz, plantviz!

end
