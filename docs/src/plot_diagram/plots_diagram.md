# `Plots.jl` recipes

```@setup usepkg
using PlantGeom
using Plots
plotlyjs()
opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf"))
```

`PlantGeom.jl` provides recipes to make plots using `Plots.jl`. The only recipe so far is to make a diagram of the MTG tree.
This is especially useful to control the integrity of and MTG (where it branches, where are the different scales...).

To use this recipe, simply use `Plots.jl` and any backend, though we recommend `PlotlyJS` to make the plot interactive.

The plot recipe provides some arguments to customize the plot:

- `mode = "2d"`: The mode for plotting, either "2d" or "3d"
- `node_color = :black`: the node color, can be a color or any MTG attribute
- `edge_color = node_color`: same as `node_color`, but for the edges
- `colormap = :viridis`: the colormap used for coloring
- `color_missing = RGBA(0, 0, 0, 0.3)`: The color used for missing values

```@example usepkg
using Plots
# import Pkg; Pkg.add("PlotlyJS")
plotlyjs()
opf = read_opf(joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf"))
plot(opf, node_color = :Length)
savefig("mtgplot.html"); nothing # hide
```

```@raw html
<object type="text/html" data="mtgplot.html" style="width:100%;height:500px;"></object>
```

The default plot is a 2D projection of the MTG, but you can also get a 3D projection using the `mode` keyword argument:

```@example usepkg
plot(opf, node_color = :Length, mode = "3d")
savefig("mtgplot3d.html"); nothing # hide
```

```@raw html
<object type="text/html" data="mtgplot3d.html" style="width:100%;height:500px;"></object>
```
