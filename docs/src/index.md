```@meta
CurrentModule = PlantGeom
```

# PlantGeom

Documentation for [PlantGeom](https://github.com/VEZY/PlantGeom.jl), a package about everything 3D-related for plants.

The package is designed around [MultiScaleTreeGraph](https://github.com/VEZY/MultiScaleTreeGraph.jl) for the basic structure of plants (or any 3D object) topology and attributes.

The package provides different functionalities, the main ones being:

- IO for the OPF file format (see [`read_opf`](@ref) and [`write_opf`](@ref));
- plotting using [`viz`](@ref) and [`viz!`](@ref), optionally using coloring by attribute;
- mesh transformations using [`transform_mesh!`](@ref)

Note that `:geometry` is a reserved attribute in nodes (*e.g.* organs) used for the 3D geometry. It is stored as a special structure ([`geometry`](@ref)).
