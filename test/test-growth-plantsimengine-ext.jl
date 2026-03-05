if Base.find_package("PlantSimEngine") === nothing
    @testset "Growth API PlantSimEngine extension" begin
        @test true
    end
else
    @eval using PlantSimEngine
    @eval using PlantSimEngine.Examples

    @testset "Growth API PlantSimEngine extension" begin
        scene_ver(node) = haskey(node, :_scene_version) ? node[:_scene_version] : 0

        mod = Process1Model(1.0)

        mtg = Node(NodeMTG(:/, :Plant, 1, 1))
        internode = Node(mtg, NodeMTG(:/, :Internode, 1, 2))
        Node(internode, NodeMTG(:+, :Leaf, 1, 2))

        mapping = PlantSimEngine.ModelMapping(
            :Plant => (
                mod,
                PlantSimEngine.Status(var1=1.0, var2=2.0),
            ),
            :Internode => (
                mod,
                PlantSimEngine.Status(var1=1.0, var2=2.0, Length=0.0, Width=0.0, Thickness=0.0),
            ),
            :Leaf => (
                mod,
                PlantSimEngine.Status(var1=1.0, var2=2.0, Length=0.0, Width=0.0, Thickness=0.0),
            ),
        )

        sim = PlantSimEngine.GraphSimulation(
            mtg,
            mapping;
            nsteps=1,
            outputs=Dict(
                :Plant => (:var3,),
                :Internode => (:var3,),
                :Leaf => (:var3,),
            ),
            check=true,
        )

        n_internodes_before = length(sim.statuses[:Internode])
        n_leaves_before = length(sim.statuses[:Leaf])

        plant_status = sim.statuses[:Plant][1]
        new_internode = emit_internode!(
            plant_status.node,
            sim;
            index=9,
            scale=2,
            link=:+,
            length=0.20,
            width=0.02,
            check=true,
            bump_scene=false,
        )
        @test new_internode isa PlantSimEngine.Status
        @test length(sim.statuses[:Internode]) == n_internodes_before + 1
        @test new_internode.node[:Length] == 0.20

        new_leaf = emit_leaf!(
            new_internode,
            sim;
            index=7,
            length=0.10,
            width=0.03,
            leaf_stage=:juvenile,
            check=true,
            bump_scene=false,
        )
        @test new_leaf isa PlantSimEngine.Status
        @test length(sim.statuses[:Leaf]) == n_leaves_before + 1
        @test new_leaf.node[:leaf_stage] == :juvenile

        phy = emit_phytomer!(
            new_internode.node,
            sim;
            internode=(length=0.12, width=0.015),
            leaf=(length=0.08, width=0.025, leaf_stage=:expanding),
            check=true,
            bump_scene=false,
        )
        @test phy.internode isa PlantSimEngine.Status
        @test phy.leaf isa PlantSimEngine.Status

        grow_length!(phy.internode; delta=0.03, bump_scene=false)
        @test phy.internode.node[:Length] ≈ 0.15

        grow_width!(phy.internode; delta=0.005, bump_scene=false)
        @test phy.internode.node[:Width] ≈ 0.02
        @test phy.internode.node[:Thickness] ≈ 0.02

        set_growth_attributes!(phy.leaf; leaf_stage=:adult, age=5, bump_scene=false)
        @test phy.leaf.node[:leaf_stage] == :adult
        @test phy.leaf.node[:age] == 5

        v0 = scene_ver(mtg)
        emit_leaf!(phy.internode, sim; length=0.05, width=0.015, bump_scene=true)
        @test scene_ver(mtg) == v0 + 1
    end
end
