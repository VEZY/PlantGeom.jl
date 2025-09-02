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
    opf = plot[mtg_name]
    color = plot[:color]

    # Get the colors for the meshes:
    colorant = Makie.@lift PlantGeom.get_mtg_color($color, opf[]) #! not using `$opf` as it would trigger the computation of the color again on change, which is not what we want here.

    if hasproperty(plot, :filter_fun) && !isnothing(plot[:filter_fun][]) #! remove the hasproperty checks when ditching the call from Meshes.viz
        user_function = plot[:filter_fun][]
        f = node -> node[:geometry] !== nothing && user_function(node)
    else
        f = node -> node[:geometry] !== nothing
    end

    symbol = hasproperty(plot, :symbol) ? plot[:symbol][] : nothing # we should lift here Makie.lift(x -> x, plot[:symbol])
    scale = hasproperty(plot, :scale) ? plot[:scale][] : nothing
    link = hasproperty(plot, :link) ? plot[:link][] : nothing

    # Optional merged rendering path (single mesh for the whole scene):
    merged = hasproperty(plot, :merged) ? plot[:merged][] : false
    if merged
        return plot_opf_merged(colorant, plot, f, symbol, scale, link, mtg_name)
    end

    plot_opf(colorant, plot, f, symbol, scale, link, mtg_name)

    return plot
end

# Merged-path rendering for simple colorant (single color only, experimental)
function plot_opf_merged(colorant::Observables.Observable{T}, plot, f, symbol, scale, link, mtg_name) where {T<:Colorant}
    opf = plot[mtg_name][]
    # Cache key based on solid color and filters
    filter_fun_user = hasproperty(plot, :filter_fun) ? plot[:filter_fun][] : nothing
    key = PlantGeom.scene_cache_key(opf; merged=true, colorant_tag=:solid, color_id=string(colorant[]),
        symbol=symbol, scale=scale, link=link, filter_fun=filter_fun_user)

    if (cached = PlantGeom.get_cached_scene(opf, key)) !== nothing
        MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = cached.face2node
        MeshesMakieExt.viz!(plot, Makie.Attributes(plot), cached.mesh, color=Makie.lift(x -> x, colorant))
        return plot
    end

    merged_mesh, face2node = PlantGeom.build_merged_mesh_with_map(opf; filter_fun=f, symbol=symbol, scale=scale, link=link)
    PlantGeom.set_cached_scene!(opf, key; mesh=merged_mesh, face2node=face2node)
    MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = face2node

    MeshesMakieExt.viz!(plot, Makie.Attributes(plot), merged_mesh, color=Makie.lift(x -> x, colorant))
    return plot
end

function plot_opf_merged(colorant::Observables.Observable{T}, plot, f, symbol, scale, link, mtg_name) where {T<:Union{PlantGeom.VectorColorant,PlantGeom.VectorSymbol}}
    opf = plot[mtg_name][]
    # Cache key based on solid color and filters
    filter_fun_user = hasproperty(plot, :filter_fun) ? plot[:filter_fun][] : nothing
    key = PlantGeom.scene_cache_key(opf; merged=true, colorant_tag=:solid, color_id=string(colorant[]),
        symbol=symbol, scale=scale, link=link, filter_fun=filter_fun_user)

    # Helper to compute mapping from node id -> index in the user-provided color vector,
    # using the same traversal and filters used to build the merged mesh and face2node.
    function node_index_map()
        ids = Int[]
        MultiScaleTreeGraph.traverse!(opf; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
            if node[:geometry] !== nothing
                push!(ids, MultiScaleTreeGraph.node_id(node))
            end
        end
        Dict(id => i for (i, id) in enumerate(ids))
    end

    if (cached = PlantGeom.get_cached_scene(opf, key)) !== nothing
        MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = cached.face2node
        id2idx = node_index_map()
        # Expand per-node colors to per-face colors using face2node mapping
        face_colors = Makie.lift(colorant) do c
            cols = c.colors
            length(id2idx) == length(cols) || error("Vector color length (", length(cols), ") does not match number of selected nodes (", length(id2idx), ").")
            # Preserve element type (Colorant or Symbol)
            out = Vector{typeof(cols[1])}(undef, length(cached.face2node))
            @inbounds for i in eachindex(cached.face2node)
                out[i] = cols[id2idx[cached.face2node[i]]]
            end
            out
        end
        MeshesMakieExt.viz!(plot, Makie.Attributes(plot), cached.mesh, color=face_colors)
        return plot
    end

    merged_mesh, face2node = PlantGeom.build_merged_mesh_with_map(opf; filter_fun=f, symbol=symbol, scale=scale, link=link)
    PlantGeom.set_cached_scene!(opf, key; mesh=merged_mesh, face2node=face2node)
    MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = face2node

    id2idx = node_index_map()
    face_colors = Makie.lift(colorant) do c
        cols = c.colors
        length(id2idx) == length(cols) || error("Vector color length (", length(cols), ") does not match number of selected nodes (", length(id2idx), ").")
        out = Vector{typeof(cols[1])}(undef, length(face2node))
        @inbounds for i in eachindex(face2node)
            out[i] = cols[id2idx[face2node[i]]]
        end
        out
    end

    MeshesMakieExt.viz!(plot, Makie.Attributes(plot), merged_mesh, color=face_colors)
    return plot
end

# Fallback when merged mode is requested with unsupported color specs
function plot_opf_merged(colorant, plot, f, symbol, scale, link, mtg_name)
    @warn "colorant type not supported: $colorant"
    return plot_opf(colorant, plot, f, symbol, scale, link, mtg_name)
end

# Merged-path rendering for attribute-based color
function plot_opf_merged(colorant::Observables.Observable{AttributeColorant}, plot, f, symbol, scale, link, mtg_name)
    opf_obs = plot[mtg_name]
    opf = opf_obs[]
    colormap_ = plot[:colormap]
    colormap = get_colormap(colormap_[])
    color_missing = hasproperty(plot, :color_missing) ? plot[:color_missing][] : RGBA(0, 0, 0, 0.3)
    color_range = get_color_range(plot[:colorrange][], opf, colorant[])
    index = isnothing(plot[:index][]) ? 1 : plot[:index][]

    # Cache key includes attribute, colormap, colorrange and filters
    filter_fun_user = hasproperty(plot, :filter_fun) ? plot[:filter_fun][] : nothing
    key = PlantGeom.scene_cache_key(opf; merged=true, colorant_tag=:attr, color_id=attr_colorant_name(colorant[]),
        colormap_id=colormap_[], colorrange_id=plot[:colorrange][],
        symbol=symbol, scale=scale, link=link, filter_fun=filter_fun_user)
    if (cached = PlantGeom.get_cached_scene(opf, key)) !== nothing
        MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = cached.face2node
        MeshesMakieExt.viz!(plot, Makie.Attributes(plot), cached.mesh, color=cached.vertex_colors, colormap=colormap)
        return plot
    end

    # Build per-node meshes, vertex-colors, and face2node mapping
    meshes = Meshes.SimpleMesh[]
    vertex_colors = Vector{Colorant}()
    face2node = Int[]
    any_node_selected = Ref(false)

    color_attr_sym = attr_colorant_name(colorant[])

    MultiScaleTreeGraph.traverse!(opf; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        geom = node[:geometry]
        if geom !== nothing
            any_node_selected[] = true
            m = geom.mesh === nothing ? PlantGeom.refmesh_to_mesh(node) : geom.mesh
            if m !== nothing
                push!(meshes, m)
                # Colors for this mesh's vertices
                val = node[color_attr_sym]
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
                append!(face2node, fill(MultiScaleTreeGraph.node_id(node), Meshes.nelements(m))) #! should we put the node directly?
            end
        end
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
    length(meshes) > 0 || error("No geometry meshes found to merge.")

    #! we should probably avoid making a vector and then merging, we can do this in one pass I think, but check that's faster. If not, at least we can use reduce(merge, meshes)
    merged_mesh = meshes[1]
    for i in 2:length(meshes)
        merged_mesh = Meshes.merge(merged_mesh, meshes[i])
    end

    PlantGeom.set_cached_scene!(opf, key; mesh=merged_mesh, vertex_colors=vertex_colors, face2node=face2node)
    MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = face2node
    MeshesMakieExt.viz!(plot, Makie.Attributes(plot), merged_mesh, color=vertex_colors, colormap=colormap)
    return plot
end

# Merged-path rendering for dict-by-refmesh colors
function plot_opf_merged(colorant::Observables.Observable{T}, plot, f, symbol, scale, link, mtg_name) where {T<:Union{DictRefMeshColorant,DictVertexRefMeshColorant}}
    opf = plot[mtg_name][]
    # Cache key based on refmesh color dict and filters
    filter_fun_user = hasproperty(plot, :filter_fun) ? plot[:filter_fun][] : nothing
    key = PlantGeom.scene_cache_key(opf; merged=true, colorant_tag=:refmesh, color_id=objectid(colorant[]),
        symbol=symbol, scale=scale, link=link, filter_fun=filter_fun_user)
    if (cached = PlantGeom.get_cached_scene(opf, key)) !== nothing
        MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = cached.face2node
        MeshesMakieExt.viz!(plot, Makie.Attributes(plot), cached.mesh, color=cached.vertex_colors)
        return plot
    end

    meshes = Meshes.SimpleMesh[]
    vertex_colors = Vector{Colorant}()
    face2node = Int[]
    any_node_selected = Ref(false)

    MultiScaleTreeGraph.traverse!(opf; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        geom = node[:geometry]
        if geom !== nothing
            any_node_selected[] = true
            m = geom.mesh === nothing ? PlantGeom.refmesh_to_mesh(node) : geom.mesh
            if m !== nothing
                push!(meshes, m)
                # Determine color from refmesh name; if a per-vertex vector is provided use it
                name = get_ref_mesh_name(node)
                c = get(colorant[].colors, name, material_single_color(geom.ref_mesh.material))
                if c isa AbstractVector{<:Colorant}
                    append!(vertex_colors, c)
                else
                    append!(vertex_colors, fill(parse(Colorant, c), Meshes.nvertices(m)))
                end
                append!(face2node, fill(MultiScaleTreeGraph.node_id(node), Meshes.nelements(m)))
            end
        end
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
    length(meshes) > 0 || error("No geometry meshes found to merge.")

    merged_mesh = meshes[1]
    for i in 2:length(meshes)
        merged_mesh = Meshes.merge(merged_mesh, meshes[i])
    end

    PlantGeom.set_cached_scene!(opf, key; mesh=merged_mesh, vertex_colors=vertex_colors, face2node=face2node)
    MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = face2node
    MeshesMakieExt.viz!(plot, Makie.Attributes(plot), merged_mesh, color=vertex_colors)
    return plot
end

# Merged-path rendering for default refmesh colors
function plot_opf_merged(colorant::Observables.Observable{RefMeshColorant}, plot, f, symbol, scale, link, mtg_name)
    opf = plot[mtg_name][]
    # Cache key for default refmesh color path
    filter_fun_user = hasproperty(plot, :filter_fun) ? plot[:filter_fun][] : nothing
    key = PlantGeom.scene_cache_key(opf; merged=true, colorant_tag=:refmesh_default, color_id=:default,
        symbol=symbol, scale=scale, link=link, filter_fun=filter_fun_user)
    if (cached = PlantGeom.get_cached_scene(opf, key)) !== nothing
        MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = cached.face2node
        MeshesMakieExt.viz!(plot, Makie.Attributes(plot), cached.mesh, color=cached.vertex_colors)
        return plot
    end

    meshes = Meshes.SimpleMesh[]
    vertex_colors = Vector{Colorant}()
    face2node = Int[]
    any_node_selected = Ref(false)

    MultiScaleTreeGraph.traverse!(opf; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        geom = node[:geometry]
        if geom !== nothing
            any_node_selected[] = true
            m = geom.mesh === nothing ? PlantGeom.refmesh_to_mesh(node) : geom.mesh
            if m !== nothing
                push!(meshes, m)
                c = material_single_color(geom.ref_mesh.material)
                append!(vertex_colors, fill(c, Meshes.nvertices(m)))
                append!(face2node, fill(MultiScaleTreeGraph.node_id(node), Meshes.nelements(m)))
            end
        end
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")
    length(meshes) > 0 || error("No geometry meshes found to merge.")

    merged_mesh = meshes[1]
    for i in 2:length(meshes)
        merged_mesh = Meshes.merge(merged_mesh, meshes[i])
    end

    PlantGeom.set_cached_scene!(opf, key; mesh=merged_mesh, vertex_colors=vertex_colors, face2node=face2node)
    MultiScaleTreeGraph.get_root(opf)[:_scene_face2node] = face2node
    MeshesMakieExt.viz!(plot, Makie.Attributes(plot), merged_mesh, color=vertex_colors)
    return plot
end

# Case where the color is a colorant (e.g. `:red`, or `RGB(0.1,0.5,0.1)`):
function plot_opf(colorant::Observables.Observable{T}, plot, f, symbol, scale, link, mtg_name) where {T<:Colorant}
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")
    any_node_selected = Ref(false)
    MultiScaleTreeGraph.traverse!(plot[mtg_name][]; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        any_node_selected[] = true
        # get the color based on a colormap and the normalized attribute value
        node[color_attr_name] = Makie.lift(x -> x, colorant)

        MeshesMakieExt.viz!(
            plot,
            Makie.Attributes(plot),
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
        )
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")

    return plot
end

# Case where the color is a vector of colors / symbols (e.g. `fill(:red, length(mtg))`):
function plot_opf(colorant::Observables.Observable{T}, plot, f, symbol, scale, link, mtg_name) where {T<:Union{PlantGeom.VectorColorant,PlantGeom.VectorSymbol}}
    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")
    any_node_selected = Ref(false)
    i = Ref(0) # index to access the color vector

    MultiScaleTreeGraph.traverse!(plot[mtg_name][]; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        i[] += 1
        any_node_selected[] = true
        # get the color based on a colormap and the normalized attribute value
        node[color_attr_name] = Makie.lift(x -> x.colors[i[]], colorant)
        MeshesMakieExt.viz!(
            plot,
            Makie.Attributes(plot),
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
        )
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")

    return plot
end

# Case where the color is a color for each reference mesh:
function plot_opf(colorant::Observables.Observable{T}, plot, f, symbol, scale, link, mtg_name) where {T<:Union{RefMeshColorant,DictRefMeshColorant,DictVertexRefMeshColorant}}

    color_attr_name = MultiScaleTreeGraph.cache_name("Color name")

    opf = plot[mtg_name]
    any_node_selected = Ref(false)

    # Make the plot, case where the color is a color for each reference mesh:
    MultiScaleTreeGraph.traverse!(opf[]; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        any_node_selected[] = true

        node[color_attr_name] = Makie.@lift color_from_refmeshes($colorant, node)
        MeshesMakieExt.viz!(
            plot,
            Makie.Attributes(plot),
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
        )
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")

    return plot
end

function color_from_refmeshes(color::RefMeshColorant, node)
    material_single_color(node.geometry.ref_mesh.material)
end

function color_from_refmeshes(color::Union{DictRefMeshColorant,DictVertexRefMeshColorant}, node)
    get(color.colors, get_ref_mesh_name(node), material_single_color(node.geometry.ref_mesh.material))
end

# Case where the color is an attribute of the MTG:
function plot_opf(colorant::Observables.Observable{AttributeColorant}, plot, f, symbol, scale, link, mtg_name)

    # Set the value of the cached color attribute (will be written in the MTG!)
    # This is usefull when we make several plots at once and need different colors at the same time (e.g. plotting the same plant on two different days).
    color_attr_name = hasproperty(plot, :color_cache_name) ? plot[:color_cache_name] : MultiScaleTreeGraph.cache_name("Color name")

    opf = plot[mtg_name]
    colormap_ = plot[:colormap]
    colormap = Makie.@lift get_colormap($colormap_)

    # Because we extend the `Viz` type, we cannot use the standard way of getting the attribute
    # from the plot. Instead, we need to check here if the argument is given, and give the default
    # value if not.
    # Note: If we defined our own e.g. `PlantViz` type, we could have defined a `color_missing` and 
    # `colorrange` fields in it directly.

    # Are the colors given for each vertex in the meshes, or for each reference mesh?
    # Note that we can have several values if we have several timesteps too.
    color_missing = hasproperty(plot, :color_missing) ? plot[:color_missing] : Observables.Observable(RGBA(0, 0, 0, 0.3))

    color_range = Makie.@lift get_color_range($(plot[:colorrange]), opf[], $colorant)
    #! Important note: we use `opf` here and not `$opf` because the code below will modify the OPF, and we don't want to trigger
    #! this again on change, as it will do a stack overflow error (infinite recursion).

    index = Makie.lift(x -> isnothing(x) ? 1 : x, plot[:index])

    any_node_selected = Ref(false)
    # Make the plot, case where the color is a color for each reference mesh:
    MultiScaleTreeGraph.traverse!(opf[]; filter_fun=f, symbol=symbol, scale=scale, link=link) do node
        any_node_selected[] = true
        color_attribute = Makie.@lift PlantGeom.attr_colorant_name($colorant) # the attribute name used for coloring

        if node[color_attribute[]] === nothing
            node[color_attr_name] = color_missing
        else
            # get the color based on a colormap and the normalized attribute value
            node[color_attr_name] = Makie.@lift get_color(node[$color_attribute], $color_range, $index; colormap=$colormap)
        end

        MeshesMakieExt.viz!(
            plot,
            Makie.Attributes(plot),
            node[:geometry].mesh === nothing ? refmesh_to_mesh(node) : node[:geometry].mesh,
            color=node[color_attr_name],
            colormap=colormap,
        )
    end
    any_node_selected[] || error("No corresponding node found for the selection given as the combination of `symbol`, `scale`, `link` and `filter_fun` arguments. ")

    return plot
end
