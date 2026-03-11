@testset "Prototype API basics" begin
    base_mesh = GeometryBasics.Mesh(
        [Point(0.0, -0.5, 0.0), Point(1.0, 0.0, 0.0), Point(0.0, 0.5, 0.0)],
        [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
    )
    base_ref = RefMesh("base_ref", base_mesh, RGB(0.2, 0.6, 0.3))

    proto_ref = RefMeshPrototype(base_ref)
    coords_ref = collect(GeometryBasics.coordinates(proto_ref.ref_mesh.mesh))
    @test minimum(p[1] for p in coords_ref) ≈ 0.0 atol = 1e-8
    @test maximum(p[1] for p in coords_ref) ≈ 1.0 atol = 1e-8

    pproto = PointMapPrototype(
        base_ref;
        defaults=(bend=0.2, tip_drop=0.1),
        attr_aliases=(bend=(:Bend, :bend), tip_drop=(:TipDrop,)),
        intrinsic_shape=params -> LaminaMidribMap(base_angle_deg=35.0, bend=params.bend, tip_drop=params.tip_drop),
    )

    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    organ = Node(mtg, NodeMTG(:/, :Leaf, 1, 2))
    organ[:Bend] = 0.4
    organ[:GeometryPrototypeOverrides] = (tip_drop=0.25,)

    params = effective_parameters(organ, pproto; overrides=(tip_drop=0.5,))
    @test params.bend == 0.4
    @test params.tip_drop == 0.5

    available = available_parameters(pproto)
    names = Set(x.name for x in available)
    @test :bend in names
    @test :tip_drop in names

    @test_throws Exception effective_parameters(organ, pproto; overrides=(unknown=1.0,))
end

@testset "RawMeshPrototype ignores size scaling" begin
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    leaf = Node(mtg, NodeMTG(:/, :Leaf, 1, 2))
    leaf[:Length] = 10.0
    leaf[:Width] = 8.0
    leaf[:Thickness] = 6.0

    raw_mesh = GeometryBasics.Mesh(
        [Point(0.0, -0.25, 0.0), Point(2.0, 0.0, 0.0), Point(0.0, 0.25, 0.0)],
        [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
    )
    raw_ref = RefMesh("raw_leaf", raw_mesh, RGB(0.3, 0.8, 0.2))
    prototypes = Dict(:Leaf => RawMeshPrototype(raw_ref))

    reconstruct_geometry_from_attributes!(mtg, prototypes; convention=default_amap_geometry_convention())
    @test haskey(leaf, :geometry)
    coords = collect(GeometryBasics.coordinates(PlantGeom.geometry_to_mesh(leaf[:geometry])))
    max_dist = maximum(norm(coords[i] - coords[j]) for i in eachindex(coords), j in eachindex(coords))
    @test max_dist ≈ norm(Point(2.0, 0.0, 0.0) - Point(0.0, 0.25, 0.0)) atol = 1e-8
end

@testset "Prototype selector resolution" begin
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    leaf = Node(mtg, NodeMTG(:/, :Leaf, 1, 2))
    leaf[:Length] = 1.0

    mesh_a = GeometryBasics.Mesh(
        [Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), Point(0.0, 0.2, 0.0)],
        [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
    )
    mesh_b = GeometryBasics.Mesh(
        [Point(0.0, 0.0, 0.0), Point(1.0, 0.0, 0.0), Point(0.0, 0.4, 0.0)],
        [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
    )
    prototypes = Dict(
        :Leaf => RawMeshPrototype(RefMesh("leaf_a", mesh_a, RGB(0.2, 0.6, 0.3))),
        :LeafB => RawMeshPrototype(RefMesh("leaf_b", mesh_b, RGB(0.2, 0.6, 0.3))),
    )

    selector = node -> symbol(node) == :Leaf ? :LeafB : nothing
    reconstruct_geometry_from_attributes!(mtg, prototypes; prototype_selector=selector, convention=default_amap_geometry_convention())
    @test leaf[:geometry].ref_mesh.name == "leaf_b"
end

@testset "Growth API writes prototype attrs" begin
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    n = emit_leaf!(
        mtg;
        link=:/,
        length=0.2,
        width=0.05,
        prototype=:LeafJuvenile,
        prototype_overrides=(bend=0.35,),
    )
    @test n[:GeometryPrototype] == :LeafJuvenile
    @test n[:GeometryPrototypeOverrides] == (bend=0.35,)
end
