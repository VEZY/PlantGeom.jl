```@meta
CurrentModule = PlantGeom
```

# PlantGeom

Documentation for [PlantGeom](https://github.com/VEZY/PlantGeom.jl), a package for everything 3D in plants.

## Introduction

The package is designed around [MultiScaleTreeGraph](https://github.com/VEZY/MultiScaleTreeGraph.jl) that serves as the basic structure for the plant topology and attributes.

!!! note
    `:geometry` is a reserved attribute used to hold each node (*e.g.* organ) 3D geometry as a special structure ([`geometry`](@ref)).

The package provides different functionalities, the main ones being:

- IO for the OPF file format (see [`read_opf`](@ref) and [`write_opf`](@ref));
- plotting using [`viz`](@ref) and [`viz!`](@ref), optionally using colouring by attribute;
- mesh transformations using [`transform_mesh!`](@ref)

## API

```@index
```

```@autodocs
Modules = [PlantGeom]
```
