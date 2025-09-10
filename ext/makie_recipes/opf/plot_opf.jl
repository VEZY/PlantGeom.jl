"""
    plot_opf(plot)

Actual workhorse function for plotting an OPF / MTG with geometry.

# Arguments

- `plot`: The plot object.

The plot object can have the following optional arguments:

- `color`: The color to be used for the plot. Can be a colorant, an attribute of the MTG, or a dictionary of colors for each reference mesh.
- `alpha`: The alpha value to be used for the plot. Should be a float between 0 and 1.
- `colormap`: The colorscheme to be used for the plot. Can be a Symbol or a ColorScheme.
- `colorrange`: The range of values to be used for the colormap. Should be a tuple of floats (optionally with units if *e.g.* z position).
- `segmentcolor`: The color to be used for the facets. Should be a colorant or a symbol of color.
- `showsegments`: A boolean indicating whether the facets should be shown or not.
- `segmentsize`: The size of the segments. Should be a float.
- `showpoints`: A boolean indicating whether the points should be shown or not.
- `color_missing`: The color to be used for missing values. Should be a colorant or a symbol of color.
- `pointsize`: The size of the points. Should be a float.
- `index`: An integer giving the index of the attribute value to be vizualised. This is useful when the attribute is a vector of values for *e.g.* each timestep.
- `color_cache_name`: The name of the color cache. Should be a string (default to a random string).
- `filter_fun`: A function to filter the nodes to be plotted. Should be a function taking a node as argument and returning a boolean.
- `symbol`: Plot only nodes with this symbol. Should be a String or a vector of.
- `scale`: Plot only nodes with this scale. Should be an Int or a vector of.
- `link`: Plot only nodes with this link. Should be a String or a vector of.
- `cache=true`: Whether to cache the results.

# Examples

```julia
using MultiScaleTreeGraph, PlantGeom, Colors

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_plant.opf")

opf = read_opf(file)

f, a, plot = plantviz(opf)
plot_opf(p)

f, a, plot = plantviz(opf, color=:red)
plot_opf(plot)

f, a, plot = plantviz(opf, color=:Length)
plot_opf(plot)

plot_opf(opf; color=Dict(1=>RGB(0.1,0.5,0.1), 2=>RGB(0.1,0.1,0.5)))

plot_opf(opf; color=:red, colormap=:viridis)

plot_opf(opf; color=:red, colormap=:viridis, segmentcolor=:red, showsegments=true)


"""
function plot_opf(plot, mtg_name=:mtg)
    # Register derived nodes on the ComputeGraph for clarity and reuse
    Makie.map!(plot.attributes, [:color, mtg_name], :colorant) do col, mtg
        PlantGeom.get_mtg_color(col, mtg)
    end
    Makie.map!(plot.attributes, [:colormap], :colormap_resolved) do cm
        get_colormap(cm)
    end
    Makie.map!(plot.attributes, [:index], :index_resolved) do idx
        isnothing(idx) ? 1 : idx
    end
    Makie.map!(plot.attributes, [:colorrange, mtg_name, :colorant], :colorrange_resolved) do cr, mtg, colorant
        get_color_range(cr, mtg, colorant)
    end

    if hasproperty(plot, :filter_fun) && !isnothing(Makie.to_value(plot[:filter_fun])) #! remove the hasproperty checks when ditching the call from Meshes.viz
        user_function = Makie.to_value(plot[:filter_fun])
        f = node -> node[:geometry] !== nothing && user_function(node)
    else
        f = node -> node[:geometry] !== nothing
    end

    symbol = hasproperty(plot, :symbol) ? Makie.to_value(plot[:symbol]) : nothing #! should be using map! here (and for all other arguments too!)
    scale = hasproperty(plot, :scale) ? Makie.to_value(plot[:scale]) : nothing
    link = hasproperty(plot, :link) ? Makie.to_value(plot[:link]) : nothing

    return plot_opf_merged(plot, f, symbol, scale, link, mtg_name, Makie.to_value(plot[:cache]))

    return plot
end

function plot_opf_merged(plot, f, symbol, scale, link, mtg_name, cache=true)
    # Compute the mesh at the scene scale:
    Makie.map!(plot.attributes, [mtg_name, :filter_fun], [:merged_mesh, :face2node]) do opf, filter_fun
        return scene_mesh!(opf, filter_fun, symbol, scale, link, cache)
    end

    compute_vertex_colors!(Makie.to_value(plot[:colorant]), plot, f, symbol, scale, link, mtg_name)

    MeshesMakieExt.viz!(plot, Makie.Attributes(plot), plot[:merged_mesh], color=plot[:vertex_colors], colormap=plot[:colormap_resolved])

    return plot
end

# Fallback for unsupported color specs
function compute_vertex_colors!(colorant, plot, f, symbol, scale, link, mtg_name)
    error("colorant type not supported: $colorant")
end

# Simple colorant (single color only, experimental)
function compute_vertex_colors!(::T, plot, f, symbol, scale, link, mtg_name) where {T<:Colorant}
    map!(plot.attributes, :colorant, :vertex_colors) do colorant
        return colorant
    end

    return plot
end

function compute_vertex_colors!(colorant_value::T, plot, f, symbol, scale, link, mtg_name) where {T<:Union{PlantGeom.VectorColorant,PlantGeom.VectorSymbol}}
    # Compute mapping from node id -> color index in the user-provided color vector using the same traversal and filters used to build the merged mesh and face2node.
    ids = Int[]
    MultiScaleTreeGraph.traverse!(Makie.to_value(plot[mtg_name]); filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        push!(ids, MultiScaleTreeGraph.node_id(node))
    end
    id2idx = Dict(id => i for (i, id) in enumerate(ids))

    # Expand per-node colors to per-face colors using face2node mapping
    map!(plot.attributes, [:colorant, :face2node], :vertex_colors) do colorant, face2node #! This is not really vertex colors, but rather facet colors
        cols = colorant.colors
        length(id2idx) == length(cols) || error("Vector color length (", length(cols), ") does not match number of selected nodes (", length(id2idx), ").")
        # Preserve element type (Colorant or Symbol)
        out = Vector{typeof(cols[1])}(undef, length(face2node))
        @inbounds for i in eachindex(face2node)
            out[i] = cols[id2idx[face2node[i]]]
        end
        out
    end

    return plot
end

# Attribute-based color
function compute_vertex_colors!(colorant_value::AttributeColorant, plot, f, symbol, scale, link, mtg_name)
    # Then, compute the colors (this one uses Makie's compute graph):
    map!(plot.attributes, [:colorant, :color_missing, :colormap_resolved, :colorrange_resolved, :index_resolved, mtg_name], :vertex_colors) do colorant, color_missing, colormap, color_range, index, opf
        color_attribute = colorant.color
        vertex_colors = Vector{Colorant}()
        MultiScaleTreeGraph.traverse!(opf; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
            geom = node[:geometry] # we need the geometry to know how many vertices there are
            m = geom.mesh === nothing ? PlantGeom.refmesh_to_mesh(node) : geom.mesh
            # Colors for this mesh's vertices
            val = node[color_attribute]
            local cols
            if val === nothing
                cols = fill(color_missing, Meshes.nvertices(m))
            else
                cols_any = get_color(val, color_range, index; colormap=colormap)
                if cols_any isa AbstractVector{<:Colorant}
                    cols = cols_any
                else
                    cols = fill(cols_any, Meshes.nvertices(m))
                end
            end
            append!(vertex_colors, cols)
        end

        return vertex_colors
    end

    return plot
end

# Dict-by-refmesh colors
function compute_vertex_colors!(colorant_value::DictRefMeshColorant, plot, f, symbol, scale, link, mtg_name)
    # Then, compute the colors (this one uses Makie's compute graph):
    map!(plot.attributes, [:colorant, :color_missing, :colormap_resolved, :colorrange_resolved, :index_resolved, mtg_name], :vertex_colors) do colorant, color_missing, colormap, color_range, index, opf
        vertex_colors = Vector{Colorant}()
        MultiScaleTreeGraph.traverse!(opf; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
            geom = node[:geometry] # we need the geometry to know how many vertices there are
            m = geom.mesh === nothing ? PlantGeom.refmesh_to_mesh(node) : geom.mesh
            # Determine color from refmesh name; if a per-vertex vector is provided use it
            name = get_ref_mesh_name(node)
            cols = get(colorant.colors, name, material_single_color(geom.ref_mesh.material))
            append!(vertex_colors, fill(cols, Meshes.nvertices(m)))
        end
        return vertex_colors
    end

    return plot
end

function compute_vertex_colors!(colorant_value::DictVertexRefMeshColorant, plot, f, symbol, scale, link, mtg_name)
    map!(plot.attributes, [:colorant, :color_missing, :colormap_resolved, :colorrange_resolved, :index_resolved, mtg_name], :vertex_colors) do colorant, color_missing, colormap, color_range, index, opf
        vertex_colors = Vector{Colorant}()
        MultiScaleTreeGraph.traverse!(opf; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
            geom = node[:geometry] # we need the geometry to know how many vertices there are
            m = geom.mesh === nothing ? PlantGeom.refmesh_to_mesh(node) : geom.mesh
            # Determine color from refmesh name; if a per-vertex vector is provided use it
            name = get_ref_mesh_name(node)
            cols = get(colorant.colors, name, fill(material_single_color(geom.ref_mesh.material), Meshes.nvertices(m)))
            append!(vertex_colors, cols)
        end
        return vertex_colors
    end

    return plot
end

# Default refmesh colors
function compute_vertex_colors!(::RefMeshColorant, plot, f, symbol, scale, link, mtg_name)
    map!(plot.attributes, [mtg_name], :vertex_colors) do opf
        vertex_colors = Vector{Colorant}()
        MultiScaleTreeGraph.traverse!(opf; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
            geom = node[:geometry] # we need the geometry to know how many vertices there are
            m = geom.mesh === nothing ? PlantGeom.refmesh_to_mesh(node) : geom.mesh
            # Determine color from refmesh name; if a per-vertex vector is provided use it
            cols = fill(material_single_color(geom.ref_mesh.material), Meshes.nvertices(m))
            append!(vertex_colors, cols)
        end
        return vertex_colors
    end

    return plot
end