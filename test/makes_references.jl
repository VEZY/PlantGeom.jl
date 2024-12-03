# using MultiScaleTreeGraph
# using PlantGeom
# using Meshes
# using CairoMakie

# Import / pre-compute
file = joinpath(dirname(dirname(pathof(PlantGeom))), "test", "files", "simple_plant.opf")
opf = read_opf(file)
meshes = get_ref_meshes(opf)
# Caching the meshes as we are plotting the opf several times:
transform!(opf, refmesh_to_mesh!)

# Make reference for ref meshes:
f, ax, p = PlantGeom.viz(meshes)
save("reference_images/refmesh_basic.png", f)

f, ax, p = viz(meshes, color=Dict("Mesh0" => :burlywood4, "Mesh1" => :springgreen4))
save("reference_images/refmesh_allcolors.png", f)

# Or just changing the color of some:
f, ax, p = viz(meshes, color=Dict("Mesh1" => :burlywood4))
save("reference_images/refmesh_somecolors.png", f)

# One color for each vertex of the refmesh 0:
vertex_color1 = get_color(1:nvertices.(get_ref_meshes(opf))[1], [1, nvertices.(get_ref_meshes(opf))[1]])
vertex_color2 = get_color(1:nvertices.(get_ref_meshes(opf))[2], [1, nvertices.(get_ref_meshes(opf))[1]])

f, ax, p = viz(
    meshes,
    color=Dict(
        "Mesh0" => vertex_color1,
        "Mesh1" => vertex_color2,
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
f, ax, p = viz(opf, color=Dict("Mesh0" => :burlywood4, "Mesh1" => :springgreen4))
save("reference_images/opf_one_color_per_ref.png", f)

# Or just changing the color of some:
f, ax, p = viz(opf, color=Dict("Mesh1" => :burlywood4))
save("reference_images/opf_one_color_one_ref.png", f)

# One color for each vertex of the refmesh 1:
vertex_color = get_color(1:nvertices.(get_ref_meshes(opf))[1], [1, nvertices.(get_ref_meshes(opf))[1]])
f, ax, p = viz(opf, color=Dict("Mesh0" => vertex_color))
save("reference_images/opf_color_ref_vertex.png", f)

# Or coloring by opf attribute, e.g. using the mesh max Z coordinates (NB: need to use
# `refmesh_to_mesh!` before, see above):
transform!(opf, :geometry => (x -> zmax(x.mesh)) => :z_max, ignore_nothing=true)
f, ax, p = viz(opf, color=:z_max)
save("reference_images/opf_color_attribute.png", f)

# Or even coloring by the value of the Z coordinates of each vertex:
transform!(opf, :geometry => (x -> [Meshes.coords(i).z for i in Meshes.vertices(x.mesh)]) => :z, ignore_nothing=true)
f, ax, p = viz(opf, color=:z, showsegments=true, color_vertex=true)
save("reference_images/opf_color_attribute_vertex.png", f)

f, ax, p = viz(opf, color=:z, color_vertex=true)
colorbar(f[1, 2], p)
save("reference_images/opf_color_attribute_colorbar.png", f)

f, ax, p = viz(opf, color=:z, colorrange=(0u"m", 50u"m"), color_vertex=true)
colorbar(f[1, 2], p)
save("reference_images/opf_color_attribute_colorbar_range.png", f)

f, ax, p = viz(opf, color=:Length, colorrange=(0, 0.2), color_cache_name=:test_color)
leaf = get_node(opf, 5)
leaf[Symbol("Observable{Any}(:test_color)")][] = RGB{Float64}(1.0, 0.0, 0.0)
save("reference_images/opf_color_attribute_observable_node.png", f)

f, ax, p = viz(opf, color=:red)
# Update with a green leaf:
leaf = get_node(opf, 5)
leaf[:_cache_d9b4f7f3c3467a55ad26f362065777c471aee4c7][] = parse(Colorant, :green)
save("reference_images/opf_color_attribute_observable_node_red_green.png", f)

# Making the whole plot blue:
p.color = :blue
save("reference_images/opf_color_attribute_observable_node_blue.png", f)

nothing # to avoid returning anything.
