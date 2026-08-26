# API

```@index
```

```@autodocs
Modules = [PlantGeom]
```

## Legacy OPS compatibility

The `LegacyOPS` submodule temporarily keeps the deprecated mutating historical
adapter for source compatibility through PlantGeom v0.20. New code should use
`plantviz(scene; show_scene_boundary=true)` or [`scene_boundary_mesh`](@ref);
both leave the MTG geometry-free.

```@docs
PlantGeom.LegacyOPS
PlantGeom.LegacyOPS.materialize_scene_boundary!
```
