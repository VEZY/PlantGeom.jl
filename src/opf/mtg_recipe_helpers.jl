"""
    coordinates!(mtg; angle = 45; force = false)

Compute dummy 3d coordinates for the mtg nodes using an alterning phyllotaxy. Used when
coordinates are missing.
Coordinates are just node attributes with reserved names: :XX, :YY and :ZZ.

# Returns

Nothing, mutates the mtg in-place (adds :XX, :YY and :ZZ to nodes).

# Examples

```julia
file = joinpath(dirname(dirname(pathof(MultiScaleTreeGraph))),"test","files","simple_plant.mtg")
mtg = read_mtg(file)
coordinates!(mtg)
DataFrame(mtg, [:XX, :YY, :ZZ])
```
"""
function coordinates!(mtg; angle=45, force=false)

    coord_in_attributes = [:XX, :YY, :ZZ] .∈ Ref(get_attributes(mtg))

    if !force && any(coord_in_attributes)
        error(
            "Coordinates for $([:XX, :YY, :ZZ][coord_in_attributes]) are already present",
            " in the mtg attributes (at least for some nodes). Use `force = true` if you ",
            "want to overwrite their values."
        )
    end

    phyllotaxy = [-1]
    # This function adds a XX, YY and ZZ coordinates of each node
    traverse!(mtg, new_pos, angle, phyllotaxy)
end

function coordinates_parent!(mtg)
    coord_in_attributes = [:XX, :YY, :ZZ] .∈ Ref(get_attributes(mtg))
    if !all(coord_in_attributes)
        error("No coordinates found in MTG. Use `coordinates!(mtg)` first.")
    end

    transform!(
        mtg,
        :XX => (x -> 1.0) => :ZZ,
        (x -> get(ancestors(x, :XX, recursivity_level=1), 1, nothing)) => :XX_from,
        (x -> get(ancestors(x, :YY, recursivity_level=1), 1, nothing)) => :YY_from,
        (x -> get(ancestors(x, :ZZ, recursivity_level=1), 1, nothing)) => :ZZ_from
    )
end

function new_pos(node, angle, phyllotaxy)

    if isroot(node)
        append!(node, (XX=0.0, YY=0.0, ZZ=0.0))
        return nothing
    end

    parent_node = parent(node)
    great_parent_node = parent(parent_node)

    if great_parent_node === nothing
        great_parent_node_XX = 0.0
        great_parent_node_YY = -1.0
    else
        great_parent_node_XX = great_parent_node[:XX]
        great_parent_node_YY = great_parent_node[:YY]
    end

    if link(node) == "/"
        extend_length = 0.2
    else
        extend_length = 1
    end

    point = extend_pos(great_parent_node_XX, great_parent_node_YY, parent_node[:XX], parent_node[:YY], extend_length)

    if link(node) == "+"
        point =
            rotate_point(
                parent_node[:XX],
                parent_node[:YY],
                point[1],
                point[2],
                phyllotaxy[1] * angle
            )

        # Change phyllotaxy for next node:
        if phyllotaxy[1] == 1
            phyllotaxy[1] = -1
        else
            phyllotaxy[1] = 1
        end
    end
    node[:XX] = point[1]
    node[:YY] = point[2]
    node[:ZZ] = 0.0

    return
end

"""
Add a new point after (x1,y1) using same direction and length relative to it
"""
function extend_pos(x0, y0, x1, y1, extend_length)
    lengthAB = sqrt((x0 - x1)^2 + (y0 - y1)^2)
    x = x1 + (x1 - x0) / lengthAB * extend_length
    y = y1 + (y1 - y0) / lengthAB * extend_length
    return x, y
end

"""
Rotate a point (x1,y1) around (x0, y0) with `angle`.
"""
function rotate_point(x0, y0, x1, y1, angle)
    angle = -angle * pi / 180
    x1 = x1 - x0
    y1 = y1 - y0
    cos_a = cos(angle)
    sin_a = sin(angle)

    x = x1 * cos_a - y1 * sin_a + x0
    y = x1 * sin_a + y1 * cos_a + y0

    return x, y
end


"""
    mtg_coordinates_df(mtg, attr; force = false)
    mtg_coordinates_df!(mtg, attr; force = false)

Extract the coordinates of the nodes of the mtg and the
coordinates of their parents (:XX_from, :YY_from, :ZZ_from) and output
a DataFrame. Optionally you can also provide an attribute to add to the
output DataFrame too by passing its name as a symbol to `attr`.

The coordinates are computed using [`coordinates!`](@ref) if missing, or if
`force = true`.
"""
function mtg_coordinates_df(mtg, attr=:YY; force=false)
    mtg_coordinates_df!(deepcopy(mtg), attr; force=force)
end

function mtg_coordinates_df!(mtg, attr=:YY; force=false)
    coord_in_attributes = [:XX, :YY, :ZZ] .∈ Ref(get_attributes(mtg))
    if !all(coord_in_attributes) || force
        if coord_in_attributes == [true, true, false] && !force
            # Only :ZZ is missing, using a dummy value:
            transform!(
                mtg,
                :XX => (x -> 0.0) => :ZZ,
            )
        else
            # :XX and/or :YY missing, recompute them
            coordinates!(mtg; force=force)
        end
    end

    # Get the coordinates of the parent of the node to draw edges:
    coordinates_parent!(mtg)

    DataFrame(mtg, unique([:XX, :YY, :ZZ, :XX_from, :YY_from, :ZZ_from, attr]))
end

function attribute_range(mtg, attr; ustrip=false)
    attr_name = attr_colorant_name(attr)
    vals =
        MultiScaleTreeGraph.descendants(
            mtg,
            attr_name,
            ignore_nothing=true
        )

    if first(vals) isa Symbol || first(vals) isa Colorant
        # If the attribute value is already a colorant or a symbol, return their unique values
        return unique(vals)
    elseif length(vals[1]) == 1
        # vals is a vector of values
        range_val = extrema(vals)
    else
        # vals is a vector of vectors, we need to compute the range of ranges
        vals_no_nothing = filter(x -> x !== nothing, vals)
        if length(vals_no_nothing) == 0
            error("No value for attribute $attr_name (all values are nothing).")
        end
        range_val = (minimum(minimum.(vals_no_nothing)), maximum(maximum.(vals_no_nothing)))
    end

    if ustrip
        return Unitful.ustrip.(range_val)
    end

    return range_val
end

attr_colorant_name(x::AttributeColorant) = x.color
attr_colorant_name(x) = x
