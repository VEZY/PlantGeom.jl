module PlantGeom

using MultiScaleTreeGraph
import MeshViz: viz, viz!, Viz

# For 3D (OPF):
import Meshes: SimpleMesh, connect, Point3, Ngon, vertices, topology, Vec, coordinates
import Makie: plottype, plot!

include("structs.jl")
include("opf/reference_meshes.jl")

# 3D Plotting (OPF):
export get_ref_meshes
export viz

end
