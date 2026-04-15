"""
    plot_opf(plot)

Actual workhorse function for plotting an OPF / MTG with geometry.

# Arguments

- `plot`: The plot object.

The plot object can have the following optional arguments:

- `color`: The color to be used for the plot. Can be a colorant, an attribute of the MTG, or a dictionary of colors for each reference mesh.
- `color_mode`: How to interpret array-valued attributes. Use `:node` for per-node/timestep values and `:vertex` for per-vertex values. `:auto` only works for scalar attributes.
- `alpha`: The alpha value to be used for the plot. Should be a float between 0 and 1.
- `colormap`: The colorscheme to be used for the plot. Can be a Symbol or a ColorScheme.
- `colorrange`: The range of values to be used for the colormap. Should be a tuple of floats (optionally with units if *e.g.* z position).
- `color_missing`: The color to be used for missing values. Should be a colorant or a symbol of color.
- `index`: An integer giving the index of the attribute value to be vizualised. Use it with `color_mode=:node` for per-timestep node values, or with `color_mode=:vertex` for per-vertex values stored as matrices or vectors of vectors.
- `color_cache_name`: The name of the color cache. Should be a string (default to a random string).
- `filter_fun`: A function to filter the nodes to be plotted. Should be a function taking a node as argument and returning a boolean.
- `symbol`: Plot only nodes with this symbol. Prefer `Symbol` (or vector/tuple of symbols).
- `scale`: Plot only nodes with this scale. Should be an Int or a vector of.
- `link`: Plot only nodes with this link. Prefer `Symbol` (or vector/tuple of symbols).
- `cache=true`: Whether to cache the results.

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom, Colors

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")

opf = read_opf(file)

f, a, plot = plantviz(opf)
plot_opf(plot)

f, a, plot = plantviz(opf, color=:red)
plot_opf(plot)

f, a, plot = plantviz(opf, color=:Length)
plot_opf(plot)

transform!(
    opf,
    (x -> [v[3] for v in GeometryBasics.coordinates(refmesh_to_mesh(x))]) => :z_vertex,
    filter_fun=node -> hasproperty(node, :geometry),
)
f, a, plot = plantviz(opf, color=:z_vertex, color_mode=:vertex)
plot_opf(plot)
```
"""
function plot_opf(plot, mtg_name=:mtg)
    # Register derived nodes on the ComputeGraph for clarity and reuse
    Makie.map!(plot.attributes, [:color, mtg_name], :colorant) do col, mtg
        PlantGeom.get_mtg_color(col, mtg)
    end
    Makie.map!(plot.attributes, [:color_mode], :color_mode_resolved) do color_mode
        PlantGeom.normalize_color_mode(color_mode)
    end
    Makie.map!(plot.attributes, [:colormap], :colormap_resolved) do cm
        get_colormap(cm)
    end
    Makie.map!(plot.attributes, [:index], :index_resolved) do idx
        isnothing(idx) ? 1 : idx
    end

    Makie.map!(plot.attributes, [:colorrange, mtg_name, :colorant, :color_mode_resolved, :index], :colorrange_resolved) do cr, mtg, colorant, color_mode, index
        if isnothing(cr) && colorant isa PlantGeom.AttributeColorant
            PlantGeom.attribute_range(mtg, colorant; ustrip=true, color_mode=color_mode, index=index)
        else
            get_color_range(cr, mtg, colorant)
        end
    end

    Makie.map!(plot.attributes, [:filter_fun], :filter_fun_resolved) do filter_fun
        if isnothing(filter_fun)
            f = node -> PlantGeom.has_geometry(node)
        else
            f = node -> PlantGeom.has_geometry(node) && filter_fun(node)
        end

        return f
    end

    return plot_opf_merged(plot, mtg_name, Makie.to_value(plot[:cache]))

    return plot
end

function plot_opf_merged(plot, mtg_name, cache=true)
    # Compute the mesh at the scene scale:
    Makie.map!(plot.attributes, [mtg_name, :filter_fun_resolved, :symbol, :scale, :link], [:merged_mesh, :face2node]) do opf, filter_fun, symbol, scale, link
        return scene_mesh!(opf, filter_fun, symbol, scale, link, cache)
    end

    compute_vertex_colors!(Makie.to_value(plot[:colorant]), plot, mtg_name)

    Makie.map!(plot.attributes, :merged_mesh, [:vertices, :faces]) do mesh
        return meshes_to_makie(mesh)
    end

    Makie.mesh!(plot, Makie.Attributes(plot), plot[:vertices], plot[:faces], color=plot[:vertex_colors], colormap=plot[:colormap_resolved], colorrange=plot[:colorrange_resolved])

    return plot
end

# Fallback for unsupported color specs
function compute_vertex_colors!(colorant, plot, mtg_name)
    error("colorant type not supported: $colorant")
end

# Simple colorant (single color only)
function compute_vertex_colors!(::T, plot, mtg_name) where {T<:Colorant}
    map!(plot.attributes, :colorant, :vertex_colors) do colorant
        return colorant
    end

    return plot
end

function compute_vertex_colors!(::PlantGeom.VectorColorant, plot, mtg_name)
    Makie.map!(plot.attributes, [mtg_name, :colorant, :filter_fun_resolved, :symbol, :scale, :link], :vertex_colors) do opf, colorant, filter_fun, symbol, scale, link
        cols = colorant.colors
        vertex_colors = Vector{Colorant}()
        n_nodes_colored = Ref(0)
        MultiScaleTreeGraph.traverse!(opf; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
            n_nodes_colored[] += 1
            nverts = PlantGeom.nvertices(PlantGeom.refmesh_to_mesh(node))
            append!(vertex_colors, fill(cols[n_nodes_colored[]], nverts))
        end

        if n_nodes_colored[] != length(cols)
            error(
                "Length of the color vector (", length(cols), ") does not match number of selected nodes for coloring (", n_nodes_colored[], "). ",
                "Please ensure that the color vector is the same length as the number of nodes that have geometry and are selected ",
                "(i.e. if `filter_fun`, `symbol`, or `scale` are used). You can check the number of selected nodes by calling ",
                "`length(descendants(mtg, :geometry; ignore_nothing=true, self=true, filter_fun=..., symbol=..., scale=...))`."
            )
        end

        return vertex_colors
    end

    return plot
end

# Attribute-based color
function compute_vertex_colors!(::AttributeColorant, plot, mtg_name)
    # Then, compute the colors (this one uses Makie's compute graph):
    map!(
        plot.attributes,
        [:colorant, :color_missing, :colormap_resolved, :colorrange_resolved, :color_mode_resolved, :index, mtg_name, :filter_fun_resolved, :symbol, :scale, :link],
        :vertex_colors
    ) do colorant, color_missing, colormap, color_range, color_mode, index, opf, filter_fun, symbol, scale, link
        color_attribute = colorant.color
        vertex_colors = Vector{Colorant}()
        MultiScaleTreeGraph.traverse!(opf; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
            m = PlantGeom.refmesh_to_mesh(node)
            nverts = PlantGeom.nvertices(m)
            val = node[color_attribute]
            values = PlantGeom.attribute_color_values_for_value(val, color_attribute; color_mode=color_mode, index=index)
            cols_any = _attribute_values_to_colors(values, color_range, colormap)
            append!(vertex_colors, _coerce_attribute_vertex_colors(cols_any, nverts, color_missing, color_attribute, color_mode))
        end

        return vertex_colors
    end

    return plot
end

@inline _attribute_is_color_like(x) = x isa Symbol || x isa Colorant

@inline _attribute_as_colorant(color::Colorant) = color
@inline _attribute_as_colorant(color) = parse(Colorant, color)

function _attribute_values_to_colors(values, color_range, colormap)
    isempty(values) && return nothing

    if length(values) == 1
        return get_color(only(values), color_range; colormap=colormap)
    elseif all(_attribute_is_color_like, values)
        return _attribute_as_colorant.(values)
    else
        return get_color(values, color_range, nothing; colormap=colormap)
    end
end

function _coerce_attribute_vertex_colors(cols_any, nverts::Int, color_missing, attr_name, color_mode::Symbol)
    if cols_any === nothing
        return fill(color_missing, nverts)
    elseif cols_any isa AbstractVector{<:Colorant}
        if color_mode === :vertex
            length(cols_any) == nverts || error(
                "Attribute $attr_name in `color_mode=:vertex` produced $(length(cols_any)) values, ",
                "but the mesh has $nverts vertices."
            )
            return Vector{Colorant}(cols_any)
        else
            length(cols_any) == 1 || error(
                "Attribute $attr_name in `color_mode=:node` produced $(length(cols_any)) values. ",
                "Use `color_mode=:vertex` for per-vertex data."
            )
            return fill(only(cols_any), nverts)
        end
    else
        return fill(cols_any, nverts)
    end
end

# Ensure a stable Vector{Colorant} regardless of whether `cols_any` is a single
# Colorant or a vector of Colorants.
@inline function _coerce_vertex_colors(cols_any, nverts::Int, color_missing)
    if cols_any === nothing
        return fill(color_missing, nverts)
    elseif cols_any isa AbstractVector{<:Colorant}
        return Vector{Colorant}(cols_any)
    else
        return fill(cols_any, nverts)
    end
end

# Dict-by-refmesh colors
function compute_vertex_colors!(::DictRefMeshColorant, plot, mtg_name)
    # Then, compute the colors (this one uses Makie's compute graph):
    map!(
        plot.attributes,
        [:colorant, :color_missing, mtg_name, :filter_fun_resolved, :symbol, :scale, :link],
        :vertex_colors
    ) do colorant, color_missing, opf, filter_fun, symbol, scale, link
        vertex_colors = Vector{Colorant}()
        MultiScaleTreeGraph.traverse!(opf; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
            m = PlantGeom.refmesh_to_mesh(node)
            # Determine color from refmesh name; if a per-vertex vector is provided use it
            name = get_ref_mesh_name(node)
            cols = get(colorant.colors, name, PlantGeom.geometry_display_color(node))
            append!(vertex_colors, fill(cols, PlantGeom.nvertices(m)))
        end
        return vertex_colors
    end

    return plot
end

function compute_vertex_colors!(::DictVertexRefMeshColorant, plot, mtg_name)
    map!(
        plot.attributes,
        [:colorant, :color_missing, mtg_name, :filter_fun_resolved, :symbol, :scale, :link],
        :vertex_colors
    ) do colorant, color_missing, opf, filter_fun, symbol, scale, link
        vertex_colors = Vector{Colorant}()
        MultiScaleTreeGraph.traverse!(opf; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
            m = PlantGeom.refmesh_to_mesh(node)
            # Determine color from refmesh name; if a per-vertex vector is provided use it
            name = get_ref_mesh_name(node)
            cols = get(colorant.colors, name, fill(PlantGeom.geometry_display_color(node), PlantGeom.nvertices(m)))
            append!(vertex_colors, cols)
        end
        return vertex_colors
    end

    return plot
end

# Default refmesh colors
function compute_vertex_colors!(::RefMeshColorant, plot, mtg_name)
    map!(plot.attributes, [mtg_name, :filter_fun_resolved, :symbol, :scale, :link], :vertex_colors) do opf, filter_fun, symbol, scale, link
        vertex_colors = Vector{Colorant}()
        MultiScaleTreeGraph.traverse!(opf; filter_fun=filter_fun, symbol=symbol, scale=scale, link=link) do node
            m = PlantGeom.refmesh_to_mesh(node)
            # Determine color from refmesh name; if a per-vertex vector is provided use it
            cols = fill(PlantGeom.geometry_display_color(node), PlantGeom.nvertices(m))
            append!(vertex_colors, cols)
        end
        return vertex_colors
    end

    return plot
end
