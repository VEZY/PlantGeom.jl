# 3D plots (meshes)

`PlantGeom` uses [`Makie.jl`](https://makie.juliaplots.org/stable/) to make 3d mesh plots. It also uses [MeshViz.jl](https://github.com/JuliaGeometry/MeshViz.jl) that is also based on Makie.

This way the plots you make using `PlantGeom` support all the nice possibilities offered by Makie, such as making sub-plots, interactive plots...

## Interactive plot

Here comes the fun part! We can make 3D representations of the plants based on the geometry of each of its nodes.

If you read your MTG from an OPF file, the 3D geometry should already be computed, so you just have to `viz()` the MTG.

Because we're plotting the interactive plot in the webpage, we must use `JSServe` first (no need when using Julia from the REPL or VS Code):

```@example 1
using JSServe
Page(exportable=true, offline=true)
```

Then we can plot our interactive 3D plant:

```@example 1
using PlantGeom, WGLMakie
WGLMakie.activate!() # hide
mtg = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf"))
viz(mtg)
```

!!! warning
    The plot may take some time to appear on your screen.

Note that the plot is interactive. This is because we use `WGLMakie` as a plotting backend. You can also use `GLMakie` for better performance, or `CairoMakie` if you want a fast, non-interactive plot.

## Colors

```@setup 2
using PlantGeom, CairoMakie, MultiScaleTreeGraph
CairoMakie.activate!()
mtg = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf"))
transform!(mtg, refmesh_to_mesh!)
ref_meshes = get_ref_meshes(mtg);
transform!(mtg, :Area => (x -> [x*i for i in 1:12]) => :dummy_var, ignore_nothing = true)
```

### Note about the backend

In this section, we will use the coffee plant provided as an example OPF file from the package. This one is more realistic than the tiny plant shown above. But because it is bigger, we will only provide static images instead of interactive plots. If you want to plot the interactive plots, you can execute the example code from below using `GLMakie` or `WGLMakie` instead of `CairoMakie` simply by replacing:

```julia
using CairoMakie
```

By:

```julia
using GLMakie
```

### Set-up

The first step is to compute the node meshes using the reference meshes and the transformation matrices. This is done very easily by mapping `refmesh_to_mesh!` to each node of the MTG like so:

```@example 2
using MultiScaleTreeGraph
transform!(mtg, refmesh_to_mesh!)
```

!!! note
    This step is optional, and not needed if only few plots are performed because it is done automatically when plotting an MTG, but the results are discarded afterward to avoid too much memory usage. If you plant to make many plots, we advise to do this step to avoid to wait a long time each time.

### Default colors

The default behavior of `viz(mtg)` -without providing colors- is to use the color of each reference mesh as the color of the corresponding node mesh. In other words, a leaf in a tree will be colored with the same color as the reference mesh used to represent it. This reference mesh is available as an attribute in the root node of the MTG. We can extract those reference meshes like so:

```@example 2
using PlantGeom, CairoMakie
CairoMakie.activate!()

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")
mtg = read_opf(file)

ref_meshes = get_ref_meshes(mtg)
```

Then we can plot them in sequence:

```@example 2
viz(ref_meshes)
```

Here we are looking at the reference meshes used to build the plant. Those meshes are then transformed by transformation matrices from each node to make the mesh of that node. So by default the color used for the nodes will be taken from these reference meshes.

If we plot the coffee plant without providing any color, we would get:

```@example 2
viz(mtg)
```

### Single color

Now we can change the color of all meshes by providing a single color:

```@example 2
viz(mtg, color = :gray87)
```

### Map color to reference meshes

We can also associate a new color to each reference mesh.

We can get the default color of each reference mesh by using:

```@example 2
get_ref_meshes_color(ref_meshes)
```

Now we know the first reference mesh is the cylinder (it is brown) and the second one is the leaf (it is green).

To update their colors we can simply pass the new colors as a dictionary mapping colors to reference meshes like so:

```@example 2
viz(mtg, color = Dict(1 => :gray87, 2 => "#42A25ABD"))
```

If we want to update the second reference mesh only (the leaves), we would do:

```@example 2
viz(mtg, color = Dict(2 => "#42A25ABD"))
```

### Map color to attributes

Maybe the most interesting coloring option is to color by attribute.

Indeed, each node in the MTG can have specific attributes, *e.g.* an area, a temperature...

You can see which attributes are available in an MTG using:

```@example 2
print(names(mtg))
```

We can see that we have an attribute called `:Area`. Let's color each organ by its area:

```@example 2
viz(mtg, color = :Area)
```

Of course all Makie commands are available. For example we can zoom-in the plot using `scale!`, and add a colorbar:

```@example 2
f, ax, p = viz(mtg, color = :Area)
CairoMakie.scale!(p, 1.5, 1.5, 1.5) # we zoom-in a little bit
CairoMakie.Colorbar(f[1,2], label = "Area")
f
```

We can see that the colorbar is only in relative values (0-1). If you need absolute values, you can use PlantGeom's colorbar instead:

```@example 2
f, ax, p = viz(mtg, color = :Area)
colorbar(f[1, 2], p)
f
```

### Map color to vertices

```julia
# Compute the z position of each vertices in each mesh:
transform!(mtg, :geometry => (x -> [Meshes.coords(i).z for i in Meshes.vertices(x.mesh)]) => :z, ignore_nothing = true)
viz(mtg, color = :z, showfacets = true, color_vertex = true)
```

!!! note
    This one is not shown because CairoMakie and WGLMakie are not compatible with coloring each vertices differently. But you can still see the results on your computer using GLMakie.

### Map time step to color

The MTG attributes can have several values, for example a value for each time step of a simulation. For example, let's make a dummy variable with 12 time-steps, each value being the area time the time step:

```@example 2
transform!(mtg, :Area => (x -> [x*i for i in 1:12]) => :dummy_var, ignore_nothing = true)
```

Now we can plot the plant with the color of each organ being the value of the dummy variable at time step 1 using the `index` keyword argument:

```@example 2
f, ax, p = viz(mtg, color = :dummy_var, index = 1)
colorbar(f[1, 2], p)
f
```

We can even make a video out of it:

```@example 2
f, ax, p = viz(mtg, color = :dummy_var, index = 1)
colorbar(f[1, 2], p)

record(f, "coffee_steps.mp4", 1:12, framerate=2) do timestep
    p.index[] = timestep
end
```

![](coffee_steps.mp4)

