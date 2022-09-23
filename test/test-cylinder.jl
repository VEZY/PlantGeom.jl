# using PlantGeom
# using MultiScaleTreeGraph
# using GLMakie
# using GeometryBasics
# using CSV
# using DataFrames

# # file = "D:/OneDrive - cirad.fr/Travail_AMAP/Projets/AGROBRANCHE/Stage_Alexis_Bonnet/backup_Biomass_evaluation_LiDAR/0-data/4-mtg_lidar_segment/A1B2.mtg"
# file = "F:/Agrobranche_Alexis_Bonnet/Biomass_evaluation_LiDAR/0-data/3-mtg_lidar_plantscan3d/5-corrected_segmentized_id/tree11h.xlsx"

# branch = read_mtg(file)

# function cylinder(node::MultiScaleTreeGraph.Node)
#     node_start = ancestors(node, [:XX, :YY, :ZZ], recursivity_level=2, symbol="S")
#     if length(node_start) != 0
#         Cylinder(
#             Point3((node_start[1][1], node_start[1][2], node_start[1][3])),
#             Point3((node[:XX], node[:YY], node[:ZZ])),
#             node[:radius]
#         )

#     end
# end

# transform!(branch, cylinder => :cyl, symbol="S")

# # scene = Scene()
# # cam3d!(scene)
# # transform!(branch, :cyl => (x -> mesh!(scene, x, color=:slategrey)), symbol="S", filter_fun=node -> node[:cyl] !== nothing)

# file_LiDAR = "D:/OneDrive - cirad.fr/Travail_AMAP/Projets/AGROBRANCHE/Architecture_reconstruction/0-data/0-LiDAR/LiDAR_branches/A1B2.asc"

# scene = Scene()
# cam3d_cad!(scene)
# LiDAR_points = CSV.read(file_LiDAR, DataFrame, header=["x", "y", "z"])
# f, ax, p = scatter!(scene, Array(LiDAR_points), color=LiDAR_points.z, markersize=30)
# transform!(branch, :cyl => (x -> mesh!(scene, x, color=:slategrey)), symbol="S", filter_fun=node -> node[:cyl] !== nothing)

# LiDAR_points = CSV.read(file_LiDAR, DataFrame, header=["x", "y", "z"])


# scene = Scene()
# cam3d_cad!(scene)
# f, ax, p = scatter!(scene, Array(LiDAR_points), color=LiDAR_points.z, markersize=30)
# ax2 = Axis(f[1,2])
# transform!(branch, :cyl => (x -> mesh!(ax2, x, color=:slategrey)), symbol="S", filter_fun=node -> node[:cyl] !== nothing)

# https://join.skype.com/NDMvH8kTsV5F



# file_LiDAR = "F:/Agrobranche_Alexis_Bonnet/Biomass_evaluation_LiDAR/0-data/2-lidar_processing/2-grouped_point_clouds/2-branches/ALLSCANS-tree11h-Cloud.txt"
# LiDAR_points = CSV.read(file_LiDAR, DataFrame, header=["x", "y", "z"])

# scene = Scene()
# cam3d_cad!(scene)
# LiDAR_points = CSV.read(file_LiDAR, DataFrame, header=["x", "y", "z"])
# f, ax, p = scatter!(scene, Array(LiDAR_points[:,1:3]), color=LiDAR_points.z, markersize=30)
# transform!(branch, :cyl => (x -> mesh!(scene, x, color=:slategrey)), symbol="S", filter_fun=node -> node[:cyl] !== nothing)

# LiDAR_points = CSV.read(file_LiDAR, DataFrame, header=["x", "y", "z"])


# scene = Scene()
# cam3d_cad!(scene)
# f, ax, p = scatter!(scene, Array(LiDAR_points), color=LiDAR_points.z, markersize=30)
# ax2 = Axis(f[1,2])
# transform!(branch, :cyl => (x -> mesh!(ax2, x, color=:slategrey)), symbol="S", filter_fun=node -> node[:cyl] !== nothing)
