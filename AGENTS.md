# Repository Guidelines

## Project Structure & Module Organization
- `src/`: Main module `PlantGeom.jl` plus focused files for geometry, OPF/OPS IO, meshes, plotting recipes, and colors. Exports are declared in `src/PlantGeom.jl`.
- `ext/`: Package extension for Makie recipes (`PlantGeomMakie.jl`) and plotting helpers under `ext/makie_recipes/`.
- `test/`: Unit/visual tests (`runtests.jl`), fixtures under `test/files/`, and golden images in `test/reference_images/`.
- `docs/`: Documenter.jl setup (`docs/make.jl`) and pages in `docs/src/`.

## Architecture Overview
- Core types: `RefMesh` (reference geometry) and `Geometry` (ref mesh, transformation, cached mesh). MTG nodes store geometry in the `:geometry` attribute.
- Transforms: built on `TransformsBase` and `Meshes` (`Translate`, `Rotate`, `Scale`, `Affine`) and composed via `→`/`SequentialTransform`; conversion to 4×4 matrices via `get_transformation_matrix`.
- Data flow: OPF/OPS parsed to MTG (`read_opf`, `read_ops`), per-node geometry computed via `refmesh_to_mesh`.
- Visualization: Makie recipes live in `ext/makie_recipes/`; `plantviz` is the high-level plotting entry. Colors come from attributes or dictionaries and are mapped with `get_colormap`/`get_color`; some values are cached with `UUIDs`-named observables.
- Interop: Heavily relies on `MultiScaleTreeGraph` for the MTG container and on `Meshes` for mesh primitives and plotting glue.

## Build, Test, and Development Commands
- Julia version: use `julia 1.10+` (see `Project.toml`).
- Install deps: `julia --project -e 'using Pkg; Pkg.instantiate()'`
- Run tests: `julia --project -e 'using Pkg; Pkg.test()'`
- Build docs: `julia --project=docs -e 'using Pkg; Pkg.instantiate(); include("docs/make.jl")'`
- Dev REPL: `julia --project` then `using Revise, PlantGeom` for fast iteration.

## Coding Style & Naming Conventions
- Indentation: 4 spaces, no tabs; keep lines reasonably short (~92–100 chars).
- Names: functions `lower_snake_case`; types `CamelCase`; constants `SCREAMING_SNAKE_CASE`.
- Modules/exports: keep exports centralized in `src/PlantGeom.jl` and group related code by folder (e.g., `opf/`, `ops/`, `meshes/`).
- Docstrings: triple-quoted with minimal examples; prefer `jldoctest` blocks when feasible.

## Testing Guidelines
- Frameworks: `Test` for unit tests, `ReferenceTests` for image-based checks, and Documenter doctests (enabled on Julia ≥ 1.10).
- Conventions: add files as `test-<feature>.jl`, include them from `runtests.jl`.
- Golden images: update only intentionally via `julia --project=test test/makes_references.jl`; commit changes in `test/reference_images/` with an explanation and, when possible, add screenshots in the PR.

## Commit & Pull Request Guidelines
- Commits: concise, imperative, and scoped (e.g., "Fix OPF rotation order", "Add colorbar to PlantViz"); reference issues like `#123` when relevant.
- PRs: include a clear description, linked issues, and screenshots for visual changes; ensure `Pkg.test()` and docs build pass locally. Maintain semver; version bumps and releases are coordinated by maintainers.
