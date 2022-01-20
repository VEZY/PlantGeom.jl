# This is a makie recipe to plot the mtg nodes and connections.

@recipe(MTGPlot, node) do scene
    Attributes(
        color = :black,
        colormap = :viridis,
    )
end


# const MTG = MTGPlot{T} where {T<:MultiScaleTreeGraph.Node}
# argument_names(::Type{<:MTG}) = (:node, :color_var) # again, optional

# plottype(::MultiScaleTreeGraph.Node) = MTGPlot{<:Tuple{MultiScaleTreeGraph.Node}}

"""
using MultiScaleTreeGraph, PlantGeom, CairoMakie

file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","simple_OPF_shapes.opf")
# file = joinpath(dirname(dirname(pathof(PlantGeom))),"test","files","coffee.opf")

opf = read_opf(file)
mtgplot(opf)

# If you need to plot the opf several times, you better cache the mesh in the node geometry
# like so:
transform!(opf, refmesh_to_mesh!)

# Then plot it again like before, and it will be faster:
viz(opf)

# We can also color the 3d plot with several options:
# With one shared color:
viz(opf, color = :red)
# One color per reference mesh:
viz(opf, color = Dict(1 => :burlywood4, 2 => :springgreen4, 3 => :burlywood4))
# Or just changing the color of some:
viz(opf, color = Dict(1 => :burlywood4))
# One color for each vertex of the refmesh 1:
viz(opf, color = Dict(1 => 1:nvertices(get_ref_meshes(opf))[1]))

# Or coloring by opf attribute, e.g. using the mesh max Z coordinates (NB: need to use
# `refmesh_to_mesh!` before, see above):
transform!(opf, :geometry => (x -> zmax(x.mesh)) => :z_max, ignore_nothing = true)
viz(opf, color = :z_max)

# Or even coloring by the value of the Z coordinates of each vertex:
transform!(opf, :geometry => (x -> [i.coords[3] for i in x.mesh.points]) => :z, ignore_nothing = true)
viz(opf, color = :z, showfacets = true)
"""
function plot!(plot::MTGPlot{<:Tuple{MultiScaleTreeGraph.Node}})

    mtg = plot[:node][]
    color = plot[:color][]
    colormap = plot[:colormap][]
    # mtg = opf
    # color = :black
    # colormap = :viridis

    if Symbol(color) in get_attributes(mtg)
        # Coloring using mtg attribute:
        df_coordinates = mtg_coordinates_df(mtg, color, force = true)
        colouring_var = df_coordinates[:, color]
        color = colouring_var ./ maximum(colouring_var)

        fig, ax, p = scatter!(
            plot,
            df_coordinates.XX,
            df_coordinates.YY,
            df_coordinates.ZZ,
            color = color,
            colormap = colormap
        )
        # ?Note: could use meshscatter! instead here

        for i in 2:size(df_coordinates, 1)
            lines!(
                plot,
                [df_coordinates.XX_from[i], df_coordinates.XX[i]],
                [df_coordinates.YY_from[i], df_coordinates.YY[i]],
                [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]],
                color = get(plot[:colormap][], [color[i-1], color[i]])
            )
        end

    elseif typeof(color) <: Colorant || typeof(color) <: String || typeof(color) <: Symbol
        df_coordinates = mtg_coordinates_df(mtg, force = true)

        fig, ax, p = scatter!(
            plot,
            df_coordinates.XX,
            df_coordinates.YY,
            df_coordinates.ZZ,
            color = color
        )
        # ?Note: could use meshscatter! instead here

        for i in 2:size(df_coordinates, 1)
            lines!(
                plot,
                [df_coordinates.XX_from[i], df_coordinates.XX[i]],
                [df_coordinates.YY_from[i], df_coordinates.YY[i]],
                [df_coordinates.ZZ_from[i], df_coordinates.ZZ[i]],
                color = color
            )
        end
    else
        error(
            "color argument should be of type Colorant ",
            "(see [Colors.jl](https://juliagraphics.github.io/Colors.jl/stable/)), or ",
            "an MTG attribute."
        )
    end

    hidedecorations!(ax)
    hidespines!(ax)

    plot
end
