_approx_mesh_value(a::Number, b::Number; atol=1e-10) = isapprox(Float64(a), Float64(b); atol=atol)

function _approx_mesh_value(a::AbstractArray, b::AbstractArray; atol=1e-10)
    length(a) == length(b) || return false
    all(_approx_mesh_value(x, y; atol=atol) for (x, y) in zip(a, b))
end

_approx_mesh_value(a, b; atol=1e-10) = a == b

function _approx_mesh(a, b; atol=1e-10)
    GeometryBasics.faces(a) == GeometryBasics.faces(b) || return false
    _approx_mesh_value(GeometryBasics.coordinates(a), GeometryBasics.coordinates(b); atol=atol)
end

@testset "write_opf: rebuilt growth plant round-trip preserves materialized meshes" begin
    stem_ref = RefMesh(
        "stem",
        GeometryBasics.mesh(
            GeometryBasics.Cylinder(
                Point(0.0, 0.0, 0.0),
                Point(1.0, 0.0, 0.0),
                0.5,
            ),
        ),
    )

    leaf_ref = lamina_refmesh(
        "leaf";
        length=1.0,
        max_width=1.0,
        n_long=36,
        n_half=7,
    )

    prototypes = Dict(
        :Internode => RefMeshPrototype(stem_ref, true),
        :Leaf => PointMapPrototype(
            leaf_ref;
            defaults=(base_angle_deg=42.0, bend=0.30, tip_drop=0.08),
            intrinsic_shape=params -> LaminaMidribMap(
                base_angle_deg=params.base_angle_deg,
                bend=params.bend,
                tip_drop=params.tip_drop,
            ),
        ),
    )

    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    first_phy = emit_phytomer!(
        plant;
        internode=(link=:/, index=1, length=0.20, width=0.022),
        leaf=(index=1, offset=0.15, length=0.22, width=0.05, thickness=0.02, y_insertion_angle=52.0),
    )
    emit_phytomer!(
        first_phy.internode;
        internode=(index=2, length=0.18, width=0.020),
        leaf=(index=2, offset=0.14, length=0.24, width=0.055, thickness=0.02, phyllotaxy=180.0, y_insertion_angle=54.0),
    )

    rebuild_geometry!(plant, prototypes; bump_scene=false)

    nodes_before = collect(MultiScaleTreeGraph.traverse(plant, node -> node))
    meshes_before = Dict(
        node_id(node) => refmesh_to_mesh(node) for node in nodes_before if PlantGeom.has_geometry(node)
    )

    tmp_file = tempname() * ".opf"
    @test_nowarn write_opf(tmp_file, plant)

    roundtrip = read_opf(tmp_file, attr_type=Dict)
    nodes_after = collect(MultiScaleTreeGraph.traverse(roundtrip, node -> node))

    @test length(nodes_before) == length(nodes_after)
    @test length(roundtrip[:ref_meshes]) == 3

    for (node_before, node_after) in zip(nodes_before, nodes_after)
        @test symbol(node_before) == symbol(node_after)
        @test scale(node_before) == scale(node_after)
        @test link(node_before) == link(node_after)

        if PlantGeom.has_geometry(node_before)
            @test PlantGeom.has_geometry(node_after)
            @test _approx_mesh(meshes_before[node_id(node_before)], refmesh_to_mesh(node_after))
        else
            @test !PlantGeom.has_geometry(node_after)
        end
    end
end
