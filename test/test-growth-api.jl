@testset "Growth API (structure-only)" begin
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    scene_ver(node) = haskey(node, :_scene_version) ? node[:_scene_version] : 0

    @test scene_ver(mtg) == 0

    internode = emit_internode!(
        mtg;
        index=1,
        link=:/,
        length=0.25,
        width=0.03,
        phyllotaxy=137.5,
        attributes=(custom_axis_tag=:main,),
    )
    @test symbol(internode) == :Internode
    @test internode[:Length] == 0.25
    @test internode[:Width] == 0.03
    @test internode[:Thickness] == 0.03
    @test internode[:custom_axis_tag] == :main
    @test scene_ver(mtg) == 1

    juvenile_leaf = emit_leaf!(
        internode;
        index=1,
        length=0.12,
        width=0.04,
        y_insertion_angle=55.0,
        leaf_stage=:juvenile,
        age=0,
    )
    adult_leaf = emit_leaf!(
        internode;
        index=2,
        length=0.13,
        width=0.045,
        y_insertion_angle=50.0,
        leaf_stage=:adult,
        age=3,
    )
    @test symbol(juvenile_leaf) == :Leaf
    @test juvenile_leaf[:leaf_stage] == :juvenile
    @test adult_leaf[:leaf_stage] == :adult

    leaf_with_azimuth = emit_leaf!(internode; index=3, length=0.10, width=0.03, azimuth=42.0, bump_scene=false)
    @test leaf_with_azimuth[:Phyllotaxy] == 42.0

    leaf_with_both = emit_leaf!(internode; index=4, length=0.10, width=0.03, phyllotaxy=120.0, azimuth=42.0, bump_scene=false)
    @test leaf_with_both[:Phyllotaxy] == 120.0

    internode_with_azimuth = emit_internode!(internode; index=5, length=0.09, width=0.02, azimuth=137.5, bump_scene=false)
    @test internode_with_azimuth[:Phyllotaxy] == 137.5

    @test scene_ver(mtg) == 3

    v0 = scene_ver(mtg)
    organ_pair = emit_internode_leaf!(
        internode;
        internode=(length=0.18, width=0.02, y_euler=2.0),
        leaf=(length=0.09, width=0.03, y_insertion_angle=48.0, leaf_stage=:expanding),
    )
    @test organ_pair.internode !== nothing
    @test organ_pair.leaf !== nothing
    @test symbol(organ_pair.internode) == :Internode
    @test symbol(organ_pair.leaf) == :Leaf
    @test scene_ver(mtg) == v0 + 1

    grow_length!(organ_pair.internode; delta=0.02, bump_scene=false)
    @test organ_pair.internode[:Length] ≈ 0.20

    grow_width!(organ_pair.internode; delta=0.01, thickness_policy=:follow_width, bump_scene=false)
    @test organ_pair.internode[:Width] ≈ 0.03
    @test organ_pair.internode[:Thickness] ≈ 0.03

    grow_width!(organ_pair.internode; delta=0.01, thickness_policy=:match_increment, bump_scene=false)
    @test organ_pair.internode[:Width] ≈ 0.04
    @test organ_pair.internode[:Thickness] ≈ 0.04

    set_growth_attributes!(organ_pair.leaf; leaf_stage=:adult, age=4, bump_scene=false)
    @test organ_pair.leaf[:leaf_stage] == :adult
    @test organ_pair.leaf[:age] == 4
end

@testset "Growth API internode/leaf pair semantics and legacy wrapper" begin
    scene_ver(node) = haskey(node, :_scene_version) ? node[:_scene_version] : 0

    function emission_signature(emitter)
        root = Node(NodeMTG(:/, :Plant, 1, 1))
        result = emitter(
            root;
            internode=(length=0.18, width=0.02),
            leaf=(length=0.09, width=0.03),
            internode_index=3,
            leaf_index=7,
            scale=2,
        )
        nodes = collect(MultiScaleTreeGraph.traverse(root, identity))
        return (
            symbols=map(symbol, nodes),
            indices=map(index, nodes),
            scales=map(scale, nodes),
            leaf_parent=symbol(parent(result.leaf)),
            scene_version=scene_ver(root),
        )
    end

    current = emission_signature(emit_internode_leaf!)
    legacy = @test_deprecated r"does not create a `:Phytomer` node" emission_signature(
        emit_phytomer!,
    )
    @test legacy == current
    @test current.symbols == [:Plant, :Internode, :Leaf]
    @test :Phytomer ∉ current.symbols
    @test current.leaf_parent == :Internode

    leaf_root = Node(NodeMTG(:/, :Plant, 1, 1))
    leaf_only = emit_internode_leaf!(leaf_root; internode=nothing, leaf=(length=0.09,))
    @test leaf_only.internode === nothing
    @test symbol(leaf_only.leaf) == :Leaf
    @test parent(leaf_only.leaf) === leaf_root

    empty_root = Node(NodeMTG(:/, :Plant, 1, 1))
    empty = emit_internode_leaf!(empty_root; internode=nothing, leaf=nothing)
    @test empty == (internode=nothing, leaf=nothing)
    @test scene_ver(empty_root) == 0
end

@testset "Growth API geometry rebuild + prototype_selector" begin
    mtg = Node(NodeMTG(:/, :Plant, 1, 1))
    scene_ver(node) = haskey(node, :_scene_version) ? node[:_scene_version] : 0
    axis = emit_internode!(mtg; index=1, link=:/, length=0.25, width=0.03, y_euler=0.0, bump_scene=false)
    leaf_j = emit_leaf!(axis; index=1, length=0.11, width=0.035, y_insertion_angle=55.0, leaf_stage=:juvenile, bump_scene=false)
    leaf_a = emit_leaf!(axis; index=2, length=0.12, width=0.04, y_insertion_angle=50.0, leaf_stage=:adult, bump_scene=false)

    stem_mesh = GeometryBasics.mesh(
        GeometryBasics.Cylinder(
            Point(0.0, 0.0, 0.0),
            Point(1.0, 0.0, 0.0),
            0.1,
        ),
    )
    leaf_default_mesh = GeometryBasics.Mesh(
        [Point(0.0, -0.1, 0.0), Point(0.0, 0.1, 0.0), Point(1.0, 0.0, 0.0)],
        [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
    )
    leaf_juvenile_mesh = GeometryBasics.Mesh(
        [Point(0.0, -0.05, 0.0), Point(0.0, 0.05, 0.0), Point(0.6, 0.0, 0.0)],
        [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
    )

    stem_ref = RefMesh("stem", stem_mesh, RGB(0.45, 0.35, 0.25))
    leaf_ref = RefMesh("leaf_default", leaf_default_mesh, RGB(0.2, 0.6, 0.25))
    leaf_juvenile_ref = RefMesh("leaf_juvenile", leaf_juvenile_mesh, RGB(0.4, 0.8, 0.35))

    ref_meshes = Dict(
        :Internode => stem_ref,
        :Leaf => leaf_ref,
    )

    selector = node -> begin
        symbol(node) == :Leaf || return nothing
        stage = haskey(node, :leaf_stage) ? node[:leaf_stage] : :adult
        stage == :juvenile ? leaf_juvenile_ref : nothing
    end

    rebuild_geometry!(mtg, ref_meshes; prototype_selector=selector, bump_scene=false)

    @test haskey(axis, :geometry)
    @test haskey(leaf_j, :geometry)
    @test haskey(leaf_a, :geometry)
    @test leaf_j[:geometry].ref_mesh.name == leaf_juvenile_ref.name
    @test leaf_a[:geometry].ref_mesh.name == leaf_ref.name

    v0 = scene_ver(mtg)
    rebuild_geometry!(mtg, ref_meshes; prototype_selector=selector, bump_scene=true)
    @test scene_ver(mtg) == v0 + 1
end
