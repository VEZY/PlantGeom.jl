```@meta
CurrentModule = PlantGeom
```

# PlantGeom

Documentation for [PlantGeom](https://github.com/VEZY/PlantGeom.jl), a package about everything 3D-related for plants.

The package is designed around [MultiScaleTreeGraph](https://github.com/VEZY/MultiScaleTreeGraph.jl) for the basic structure of plants (or any 3D object) topology and attributes.

The package provides different functionalities, the main ones being:

- IO for the OPF file format (see [`read_opf`](@ref) and [`write_opf`](@ref));
- plotting using `plantviz` and `plantviz!`, optionally using coloring by attribute. Rendering is merged-by-default for performance;
- mesh transformations using [`transform_mesh!`](@ref)

Note that PlantGeom reserves the `:geometry` attribute in the nodes (*e.g.* organs). It uses it to store the 3D geometry as a special structure ([`Geometry`](@ref)).

```@setup animation
using CairoMakie, Meshes, PlantGeom, MultiScaleTreeGraph # Note: CairoMakie must be loaded before PlantGeom to access the extensions
using Bonito
Page()
opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf"))

# And compute the max z of each node based on their mesh:
transform!(opf, zmax => :z_node, ignore_nothing = true)
# Or the z coordinate of each vertez of each node mesh:
transform!(opf, (x -> [Meshes.coords(i).z for i in Meshes.vertices(refmesh_to_mesh(x))]) => :z_vertex, filter_fun= node -> hasproperty(node, :geometry))

# Then we make a Makie figure:
f = Figure()
ga = f[1, 1]
gb = f[1, 2]

ax1 = Axis(ga[1, 1])
ax2 = Axis3(gb[1, 1], aspect = :data, title = "3D representation (mesh)", elevation = 0.15π, azimuth = 0.3π)
hidedecorations!(ax2)

# We can make a diagram out of the MTG, and coloring using the z coordinates attribute:
diagram!(ax1, opf, color = :z_node)
hidedecorations!(ax1)
ax1.title = "MultiscaleTreeGraph diagram"

# And a 3d representation:

plantviz!(opf, color = :z_vertex)

# And making a little animation out of it:
CairoMakie.record(f, "plant_animation.mp4", 1:120) do frame
    ax2.azimuth[] = 0.3π + 0.3 * sin(2π * frame / 120)
end
```

![](plant_animation.mp4)

If you want to reproduce the animation, you can look at the code below. Otherwise, please head to the next section.

```julia
using CairoMakie, Meshes, PlantGeom, MultiScaleTreeGraph
opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf"))
# And compute the max z of each node based on their mesh:
transform!(opf, zmax => :z_node, ignore_nothing = true)
# Or the z coordinate of each vertex of each node mesh:
transform!(opf, (x -> [Meshes.coords(i).z for i in Meshes.vertices(refmesh_to_mesh(x))]) => :z_vertex, filter_fun= node -> hasproperty(node, :geometry))

# Then we make a Makie figure:
f = Figure()
ga = f[1, 1]
gb = f[1, 2]

ax1 = Axis(ga[1, 1])
ax2 = Axis3(gb[1, 1], aspect = :data, title = "3D representation (mesh)", elevation = 0.15π, azimuth = 0.3π)
hidedecorations!(ax2)

# We can make a diagram out of the MTG, and coloring using the z coordinates attribute:
diagram!(ax1, opf, color = :z_node)
hidedecorations!(ax1)
ax1.title = "MultiscaleTreeGraph diagram"

# And a 3d representation:

plantviz!(opf, color = :z_vertex)

# And making a little animation out of it:
CairoMakie.record(f, "plant_animation.mp4", 1:120) do frame
    ax2.azimuth[] = 0.3π + 0.3 * sin(2π * frame / 120)
end
```
