_approx_value(a::Number, b::Number; atol=1e-10) = isapprox(Float64(a), Float64(b); atol=atol)

function _approx_value(a::AbstractArray, b::AbstractArray; atol=1e-10)
    length(a) == length(b) || return false
    all(_approx_value(x, y; atol=atol) for (x, y) in zip(a, b))
end

_approx_value(a, b; atol=1e-10) = a == b

function _approx_ref_mesh(a, b; atol=1e-10)
    a.name == b.name || return false
    a.material == b.material || return false
    a.taper == b.taper || return false
    GeometryBasics.faces(a.mesh) == GeometryBasics.faces(b.mesh) || return false
    _approx_value(GeometryBasics.coordinates(a.mesh), GeometryBasics.coordinates(b.mesh); atol=atol) || return false
    _approx_value(a.normals, b.normals; atol=atol) || return false

    if isnothing(a.texture_coords) || isnothing(b.texture_coords)
        return isnothing(a.texture_coords) && isnothing(b.texture_coords)
    end

    _approx_value(a.texture_coords, b.texture_coords; atol=atol)
end

function _approx_geometry(a, b; atol=1e-10)
    a.ref_mesh.name == b.ref_mesh.name || return false
    _approx_value(a.dUp, b.dUp; atol=atol) || return false
    _approx_value(a.dDwn, b.dDwn; atol=atol) || return false
    isapprox(get_transformation_matrix(a.transformation), get_transformation_matrix(b.transformation); atol=atol)
end

function _approx_node(a, b; atol=1e-10)
    sort(collect(keys(a))) == sort(collect(keys(b))) || return false
    symbol(a) == symbol(b) || return false
    scale(a) == scale(b) || return false
    link(a) == link(b) || return false

    for key in keys(a)
        va = a[key]
        vb = b[key]
        if key == :ref_meshes
            keys(va) == keys(vb) || return false
            for mesh_id in keys(va)
                _approx_ref_mesh(va[mesh_id], vb[mesh_id]; atol=atol) || return false
            end
        elseif key == :geometry
            if isnothing(va) || isnothing(vb)
                va == vb || return false
            else
                _approx_geometry(va, vb; atol=atol) || return false
            end
        else
            _approx_value(va, vb; atol=atol) || return false
        end
    end

    true
end

function _approx_roundtrip(mtg, mtg2; atol=1e-10)
    nodes1 = collect(MultiScaleTreeGraph.traverse(mtg, node -> node))
    nodes2 = collect(MultiScaleTreeGraph.traverse(mtg2, node -> node))
    length(nodes1) == length(nodes2) || return false
    all(_approx_node(a, b; atol=atol) for (a, b) in zip(nodes1, nodes2))
end

tmp_file = tempname()
@testset "write_opf: read, write, read again and compare -> simple_plant" begin
    mtg = read_opf("files/simple_plant.opf", attr_type=Dict)
    PlantGeom.write_opf(tmp_file, mtg)
    mtg2 = read_opf(tmp_file, attr_type=Dict)
    @test _approx_roundtrip(mtg, mtg2)
end

@testset "write_opf: read, write, read again and compare -> coffee" begin
    mtg = read_opf("files/coffee.opf", attr_type=Dict)
    PlantGeom.write_opf(tmp_file, mtg)
    mtg2 = read_opf(tmp_file, attr_type=Dict)
    @test _approx_roundtrip(mtg, mtg2)
end
