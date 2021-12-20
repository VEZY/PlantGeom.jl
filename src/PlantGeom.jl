module PlantGeom

using MultiScaleTreeGraph
import MeshViz: viz, viz!, Viz

# For 3D (OPF):
import Meshes: SimpleMesh, connect, Point3, Ngon, vertices, topology, Vec, coordinates
import Meshes: nvertices, nelements
import Makie: plot!, Attributes
import Colors: RGBA, Colorant

include("structs.jl")
include("helpers.jl")
include("opf/reference_meshes.jl")
include("makie_recipes.jl")

# 3D Plotting (OPF):
export get_ref_meshes
export viz
export nvertices, nelements

end
