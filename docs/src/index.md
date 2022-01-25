```@meta
CurrentModule = PlantGeom
```

# PlantGeom

Documentation for [PlantGeom](https://github.com/VEZY/PlantGeom.jl), a package about everything 3D-related for plants.

## Introduction

The package is designed around [MultiScaleTreeGraph](https://github.com/VEZY/MultiScaleTreeGraph.jl) that serves as the basic structure for the plant topology and attributes.

!!! note
    `:geometry` is a reserved attribute used to hold each node (*e.g.* organ) 3D geometry as a special structure ([`geometry`](@ref)).

The package provides different functionalities, the main ones being:

- IO for the OPF file format (see [`read_opf`](@ref) and [`write_opf`](@ref));
- plotting using [`viz`](@ref) and [`viz!`](@ref) for explicit 3D plotting, optionally using colouring by attribute, and [`diagram`](@ref) for plotting a diagram of the MTG tree;
- mesh transformations using [`transform_mesh!`](@ref)
