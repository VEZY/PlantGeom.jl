# using MultiScaleTreeGraph
# using PlantGeom
# using CairoMakie

# Import / pre-compute
file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)
# Caching the meshes as we are plotting the opf several times:
transform!(opf, refmesh_to_mesh!)

# Make reference for ref meshes:
f, ax, p = viz(meshes)
save("reference_images/refmesh_basic.png", f)

f, ax, p = viz(meshes, color=[:burlywood4, :springgreen4, :burlywood4])
save("reference_images/refmesh_allcolors.png", f)

# Or just changing the color of some:
f, ax, p = viz(meshes, color=Dict(1 => :burlywood4, 3 => :burlywood4))
save("reference_images/refmesh_somecolors.png", f)

# One color for each vertex of the refmesh 0:
f, ax, p = viz(
    meshes,
    color=Dict(
        1 => 1:nvertices(meshes)[1],
        2 => 1:nvertices(meshes)[2],
        3 => 1:nvertices(meshes)[3]
    )
)
save("reference_images/refmesh_vertex_colors.png", f)


# OPF recipe
# Regular plot:
f, ax, p = viz(opf)
save("reference_images/opf_basic.png", f)

# With one shared color:
f, ax, p = viz(opf, color=:red)
save("reference_images/opf_one_color.png", f)

# One color per reference mesh:
f, ax, p = viz(opf, color=Dict(1 => :burlywood4, 2 => :springgreen4, 3 => :burlywood4))
save("reference_images/opf_one_color_per_ref.png", f)

# Or just changing the color of some:
f, ax, p = viz(opf, color=Dict(1 => :burlywood4))
save("reference_images/opf_one_color_one_ref.png", f)

# One color for each vertex of the refmesh 1:
f, ax, p = viz(opf, color=Dict(1 => 1:nvertices(get_ref_meshes(opf))[1]))
save("reference_images/opf_color_ref_vertex.png", f)

# Or coloring by opf attribute, e.g. using the mesh max Z coordinates (NB: need to use
# `refmesh_to_mesh!` before, see above):
transform!(opf, :geometry => (x -> zmax(x.mesh)) => :z_max, ignore_nothing=true)
f, ax, p = viz(opf, color=:z_max)
save("reference_images/opf_color_attribute.png", f)

# Or even coloring by the value of the Z coordinates of each vertex:
transform!(opf, :geometry => (x -> [i.coords[3] for i in x.mesh.vertices]) => :z, ignore_nothing=true)
f, ax, p = viz(opf, color=:z, showfacets=true)
save("reference_images/opf_color_attribute_vertex.png", f)

f, ax, p = viz(opf, color=:z)
colorbar(f[1, 2], p)
f
save("reference_images/opf_color_attribute_colorbar.png", f)

nothing # to avoid returning anything.
