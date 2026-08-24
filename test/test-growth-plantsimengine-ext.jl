const _plantsimengine_repo = normpath(joinpath(pkgdir(PlantGeom), "..", "PlantSimEngine"))
if Base.find_package("PlantSimEngine") === nothing && isdir(_plantsimengine_repo)
    pushfirst!(LOAD_PATH, _plantsimengine_repo)
end

if Base.find_package("PlantSimEngine") === nothing
    @testset "Growth API PlantSimEngine extension" begin
        @test true
    end
else
    @eval using PlantSimEngine

    @testset "Growth API PlantSimEngine extension" begin
        scene_ver(node) = haskey(node, :_scene_version) ? node[:_scene_version] : 0

        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        internode = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        Node(internode, NodeMTG(:+, :Leaf, 1, 2))

        function initial_status(node)
            status = PlantSimEngine.Status(node=node, var1=1.0, var2=2.0)
            node[:plantsimengine_status] = status
            return status
        end

        scene = PlantSimEngine.CompositeModel(mtg; status=initial_status)
        n_internodes_before = length(PlantSimEngine.model_objects(scene; scale=:Internode))
        n_leaves_before = length(PlantSimEngine.model_objects(scene; scale=:Leaf))

        plant_status = only(PlantSimEngine.model_objects(scene; scale=:Plant)).status
        new_internode = emit_internode!(
            plant_status.node,
            scene;
            index=9,
            scale=2,
            link=:+,
            length=0.20,
            width=0.02,
            initial_status=(var1=1.0, var2=2.0),
            bump_scene=false,
        )
        @test new_internode isa PlantSimEngine.Status
        @test node_id(new_internode.node) == 4
        @test length(PlantSimEngine.model_objects(scene; scale=:Internode)) ==
              n_internodes_before + 1
        @test new_internode.node[:Length] == 0.20
        @test new_internode.Length == 0.20

        new_leaf = emit_leaf!(
            new_internode,
            scene;
            index=7,
            length=0.10,
            width=0.03,
            initial_status=(var1=1.0, var2=2.0),
            leaf_stage=:juvenile,
            bump_scene=false,
        )
        @test new_leaf isa PlantSimEngine.Status
        @test node_id(new_leaf.node) == 5
        @test length(PlantSimEngine.model_objects(scene; scale=:Leaf)) == n_leaves_before + 1
        @test new_leaf.node[:leaf_stage] == :juvenile
        @test new_leaf.leaf_stage == :juvenile

        organ_pair = emit_internode_leaf!(
            new_internode.node,
            scene;
            internode=(
                length=0.12,
                width=0.015,
                initial_status=(var1=1.0, var2=2.0),
            ),
            leaf=(
                length=0.08,
                width=0.025,
                leaf_stage=:expanding,
                initial_status=(var1=1.0, var2=2.0),
            ),
            bump_scene=false,
        )
        @test organ_pair.internode isa PlantSimEngine.Status
        @test organ_pair.leaf isa PlantSimEngine.Status

        grow_length!(organ_pair.internode; delta=0.03, bump_scene=false)
        @test organ_pair.internode.node[:Length] ≈ 0.15

        grow_width!(organ_pair.internode; delta=0.005, bump_scene=false)
        @test organ_pair.internode.node[:Width] ≈ 0.02
        @test organ_pair.internode.node[:Thickness] ≈ 0.02

        set_growth_attributes!(organ_pair.leaf; leaf_stage=:adult, age=5, bump_scene=false)
        @test organ_pair.leaf.node[:leaf_stage] == :adult
        @test organ_pair.leaf.node[:age] == 5

        @test PlantSimEngine.bindings_dirty(scene)
        v0 = scene_ver(mtg)
        emit_leaf!(
            organ_pair.internode,
            scene;
            length=0.05,
            width=0.015,
            initial_status=(var1=1.0, var2=2.0),
            bump_scene=true,
        )
        @test scene_ver(mtg) == v0 + 1

        legacy_pair = @test_deprecated r"does not create a `:Phytomer` node" emit_phytomer!(
            new_internode.node,
            scene;
            internode=(
                length=0.07,
                width=0.01,
                initial_status=(var1=1.0, var2=2.0),
            ),
            leaf=(
                length=0.04,
                width=0.01,
                initial_status=(var1=1.0, var2=2.0),
            ),
            bump_scene=false,
        )
        @test legacy_pair.internode isa PlantSimEngine.Status
        @test legacy_pair.leaf isa PlantSimEngine.Status
        @test symbol(legacy_pair.internode.node) == :Internode
        @test symbol(legacy_pair.leaf.node) == :Leaf

        legacy_empty = @test_deprecated r"does not create a `:Phytomer` node" emit_phytomer!(
            plant_status,
            scene;
            internode=nothing,
            leaf=nothing,
            bump_scene=false,
        )
        @test legacy_empty == (internode=nothing, leaf=nothing)
    end
end
