@testset "explicit organs retain world coordinates beside inclined terrain" begin
    point_type = GeometryBasics.Point{3,Float64}
    face = GeometryBasics.TriangleFace{Int}(1, 2, 3)
    terrain_points = point_type[
        point_type(-1.0, -1.0, 0.0),
        point_type(2.0, -1.0, 0.6),
        point_type(-1.0, 2.0, 0.3),
    ]
    terrain_mesh = GeometryBasics.Mesh(terrain_points, [face])
    organ_mesh = GeometryBasics.Mesh(
        point_type[
            point_type(0.0, 0.0, 0.0),
            point_type(1.0, 0.0, 0.0),
            point_type(0.0, 0.1, 0.0),
        ],
        [face],
    )
    plant = Node(NodeMTG(:/, :Plant, 1, 1))
    starts = (SVector(0.0, 0.0, 0.3), SVector(0.4, 0.2, 1.1))
    ends = (SVector(0.4, 0.2, 1.1), SVector(0.6, 0.3, 1.5))
    organs = typeof(plant)[]
    for i in 1:2
        organ = Node(
            i == 1 ? plant : organs[end],
            NodeMTG(i == 1 ? :/ : :<, :Internode, i, 2),
            Dict{Symbol,Any}(
                :XX => starts[i][1], :YY => starts[i][2], :ZZ => starts[i][3],
                :EndX => ends[i][1], :EndY => ends[i][2], :EndZ => ends[i][3],
                # Explicit endpoints override these contradictory attributes.
                :Length => 9.0, :Width => 0.2, :Thickness => 0.1,
                :YInsertionAngle => 1.2, :Azimuth => 123.0,
            ),
        )
        push!(organs, organ)
    end
    reconstruct_geometry_from_attributes!(
        plant,
        Dict(:Internode => RefMeshPrototype(
            RefMesh("explicit organ", organ_mesh);
            normalize=false,
            warn=false,
            length_axis=:x,
        ));
        convention=default_amap_geometry_convention(angle_unit=:rad),
        amap_options=AmapReconstructionOptions(
            coordinate_delegate_mode=:explicit_start_end_required,
            auto_compute_branching_order=false,
            allometry_enabled=false,
        ),
        root_align=false,
    )

    function geometry_meshes(root)
        nodes = traverse(root, identity; filter_fun=PlantGeom.has_geometry)
        return [refmesh_to_mesh(node) for node in nodes]
    end

    function meshes_match(actual, expected; factor=1.0)
        length(actual) == length(expected) || return false
        return all(zip(actual, expected)) do (actual_mesh, expected_mesh)
            GeometryBasics.faces(actual_mesh) == GeometryBasics.faces(expected_mesh) || return false
            actual_points = collect(GeometryBasics.coordinates(actual_mesh))
            expected_points = collect(GeometryBasics.coordinates(expected_mesh))
            length(actual_points) == length(expected_points) || return false
            return all(zip(actual_points, expected_points)) do (actual_point, expected_point)
                all(isapprox(actual_point[j], factor * expected_point[j]; atol=1e-10) for j in 1:3)
            end
        end
    end

    for (i, organ) in enumerate(organs)
        geometry = organ[:geometry]
        @test geometry.transformation(SVector(0.0, 0.0, 0.0)) ≈ starts[i] atol=1e-12
        @test geometry.transformation(SVector(1.0, 0.0, 0.0)) ≈ ends[i] atol=1e-12
        coordinates = collect(GeometryBasics.coordinates(refmesh_to_mesh(organ)))
        @test coordinates[1] ≈ starts[i] atol=1e-12
        @test coordinates[2] ≈ ends[i] atol=1e-12
    end
    # The first organ begins on z = 0.2x + 0.1y + 0.3, the inclined mesh plane.
    @test starts[1][3] ≈ 0.2 * starts[1][1] + 0.1 * starts[1][2] + 0.3

    original_plant_meshes = geometry_meshes(plant)
    placement = SVector(0.25, -0.5, 0.2)
    scene_m = make_scene(domain=(-2.0, -2.0, 4.0, 4.0), units=SceneUnits(length=u"m")) do builder
        add_object!(builder, terrain_mesh; group="terrain", id=1, type="Terrain", at=placement,
                    geometry_length_unit=u"m")
        add_plant!(builder, plant; group="plants", id=2, at=placement, geometry_length_unit=u"m")
    end
    scene_cm = make_scene(domain=(-200.0, -200.0, 400.0, 400.0), units=SceneUnits(length=u"cm")) do builder
        add_object!(builder, terrain_mesh; group="terrain", id=1, type="Terrain", at=100 .* placement,
                    geometry_length_unit=u"m")
        add_plant!(builder, plant; group="plants", id=2, at=100 .* placement, geometry_length_unit=u"m")
    end
    @test scene_length_unit(scene_m) == u"m"
    @test scene_area_unit(scene_m) == u"m^2"
    @test scene_length_unit(scene_cm) == u"cm"
    @test scene_area_unit(scene_cm) == u"cm^2"
    @test length(scene_node_ids(scene_m)) == 3
    @test meshes_match(geometry_meshes(scene_cm.mtg), geometry_meshes(scene_m.mtg); factor=100.0)
    @test meshes_match(geometry_meshes(plant), original_plant_meshes)
    @test collect(GeometryBasics.coordinates(terrain_mesh)) == terrain_points
    placed_terrain = first(geometry_meshes(scene_m.mtg))
    @test collect(GeometryBasics.coordinates(placed_terrain)) ≈ terrain_points .+ Ref(placement) atol=1e-12

    mktempdir() do directory
        # Both OPF coordinate conventions preserve the same internal geometry
        # when the matching scale is supplied on read and write.
        for coordinate_scale in (1.0, 100.0)
            path = joinpath(directory, "explicit-$(Int(coordinate_scale)).opf")
            write_opf(path, plant; coordinate_scale)
            reloaded = read_opf(path; coordinate_scale, mtg_type=NodeMTG)
            @test meshes_match(geometry_meshes(reloaded), original_plant_meshes)
            reloaded_organs = traverse(reloaded, identity; filter_fun=PlantGeom.has_geometry)
            @test [node[:XX] for node in reloaded_organs] ≈ [point[1] for point in starts]
            @test [node[:EndZ] for node in reloaded_organs] ≈ [point[3] for point in ends]
        end

        path = joinpath(directory, "inclined-terrain.ops")
        expected = geometry_meshes(scene_m.mtg)
        write_ops(path, scene_m.mtg)
        reloaded = read_ops(path; mtg_type=NodeMTG)
        @test reloaded.scene_dimensions == scene_m.mtg.scene_dimensions
        @test [node.functional_group for node in children(reloaded)] == ["terrain", "plants"]
        @test meshes_match(geometry_meshes(reloaded), expected)
        @test length(geometry_meshes(first(children(reloaded)))) == 1
        @test length(geometry_meshes(last(children(reloaded)))) == 2
        @test meshes_match(geometry_meshes(scene_m.mtg), expected)
    end
end
