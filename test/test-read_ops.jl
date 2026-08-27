file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene.ops")
@testset "read_ops" begin
    ops = @test_nowarn read_ops(file)
    @test ops.scene_dimensions == (GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0), GeometryBasics.Point{3,Float64}(2.0, 1.0, 0.0))
    @test length(get_ref_meshes(ops)) == 4
    @test !PlantGeom.has_geometry(ops)
    # There are only 4 reference meshes because the same OPF file is reused for
    # the simple plants. The OPS plot boundary remains metadata rather than a
    # synthetic mesh on the Scene root.
    opfs = children(ops)
    length(opfs) == 6
    opfs[1].filePath == "coffee.opf"
    [@test(p.filePath == "simple_plant.opf") for p in opfs[2:end]]
    @test [p.plantID for p in opfs] == collect(1:6)
    @test [p.sceneID for p in opfs] == fill(1, 6)
    @test opfs[1].pos == GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0)
    @test opfs[6].pos == GeometryBasics.Point{3,Float64}(2.0, 1.0, 0.0)
    [@test(p.scale == 1.5) for p in opfs[[3, 5]]]
    [@test(p.scale == 1.0) for p in opfs[[1, 2, 4, 6]]]
    [@test(p.inclinationAngle == 0.0) for p in opfs]
    [@test(p.inclinationAzimut == 0.0) for p in opfs]
    [@test(p.rotation == 0.0) for p in opfs[[1, 2, 3, 6]]]
    [@test(p.rotation == 1.57) for p in opfs[[4, 5]]]
    @test ops[1].functional_group == "coffee"
    [@test(p.functional_group == "plant") for p in opfs[2:end]]
    length_values = @test_nowarn descendants(ops, :Length; ignore_nothing=true)
    @test !isempty(length_values)
end

@testset "OPS scene boundary is a pure visualization mesh" begin
    ops = @test_nowarn read_ops(file)
    keys_before = Set(keys(ops))
    version_before = scene_version(ops)
    ref_mesh_count_before = length(get_ref_meshes(ops))
    geometry_nodes_before = MultiScaleTreeGraph.traverse(
        ops,
        identity;
        filter_fun=PlantGeom.has_geometry,
    )
    geometry_node_ids_before = MultiScaleTreeGraph.node_id.(geometry_nodes_before)
    surface_count_before = sum(
        PlantGeom.nelements(refmesh_to_mesh(node)) for node in geometry_nodes_before
    )

    boundary = @test_nowarn scene_boundary_mesh(ops)
    @test collect(GeometryBasics.coordinates(boundary)) == [
        GeometryBasics.Point{3,Float64}(0.0, 0.0, 0.0),
        GeometryBasics.Point{3,Float64}(2.0, 0.0, 0.0),
        GeometryBasics.Point{3,Float64}(2.0, 1.0, 0.0),
        GeometryBasics.Point{3,Float64}(0.0, 1.0, 0.0),
    ]
    @test length(GeometryBasics.faces(boundary)) == 2
    @test !PlantGeom.has_geometry(ops)
    @test Set(keys(ops)) == keys_before
    @test scene_version(ops) == version_before
    @test length(get_ref_meshes(ops)) == ref_mesh_count_before
    geometry_nodes_after = MultiScaleTreeGraph.traverse(
        ops,
        identity;
        filter_fun=PlantGeom.has_geometry,
    )
    @test MultiScaleTreeGraph.node_id.(geometry_nodes_after) == geometry_node_ids_before
    @test sum(
        PlantGeom.nelements(refmesh_to_mesh(node)) for node in geometry_nodes_after
    ) == surface_count_before

    mktempdir() do tmp
        before_file = joinpath(tmp, "before.ops")
        after_file = joinpath(tmp, "after.ops")
        @test_nowarn write_ops(
            before_file,
            ops;
            write_objects=false,
            preserve_file_paths=true,
        )
        @test_nowarn scene_boundary_mesh(ops)
        @test_nowarn write_ops(
            after_file,
            ops;
            write_objects=false,
            preserve_file_paths=true,
        )
        @test read(before_file, String) == read(after_file, String)
    end

    no_dimensions = read_opf(
        joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "simple_plant.opf"),
    )
    @test_throws ArgumentError scene_boundary_mesh(no_dimensions)
end

@testset "read_ops applies inclination transforms" begin
    files_dir = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files")
    mktempdir() do tmp
        cp(joinpath(files_dir, "simple_plant.opf"), joinpath(tmp, "simple_plant.opf"); force=true)

        x, y, z = 0.4, -0.2, 0.3
        scale = 1.25
        inclination_azimut = 0.35
        inclination_angle = 0.42
        rotation = 0.17

        ops_path = joinpath(tmp, "scene_inclined.ops")
        open(ops_path, "w") do io
            println(io, "T 0.0 0.0 0.0 2.0 1.0 flat")
            println(io, "#[Archimed] plant")
            println(
                io,
                "1\t1\tsimple_plant.opf\t$(x)\t$(y)\t$(z)\t$(scale)\t$(inclination_azimut)\t$(inclination_angle)\t$(rotation)",
            )
        end

        scene = @test_nowarn read_ops(ops_path)
        opf = only(children(scene))

        axis = SVector(-sin(inclination_azimut), cos(inclination_azimut), 0.0)
        axis = axis / norm(axis)

        expected_tf = PlantGeom.IdentityTransformation()
        expected_tf = PlantGeom.LinearMap(PlantGeom.RotZ(rotation)) ∘ expected_tf
        expected_tf = PlantGeom.LinearMap(Diagonal(SVector(scale, scale, scale))) ∘ expected_tf
        expected_tf = PlantGeom.LinearMap(PlantGeom.RotMatrix(PlantGeom.AngleAxis(inclination_angle, axis[1], axis[2], axis[3]))) ∘ expected_tf
        expected_tf = PlantGeom.Translation(x, y, z) ∘ expected_tf

        got_mat = PlantGeom.transformation_matrix4(opf.scene_transformation)
        expected_mat = PlantGeom.transformation_matrix4(expected_tf)
        @test maximum(abs.(got_mat .- expected_mat)) < 1e-12
    end
end

legacy_file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene_legacy.ops")
@testset "read_ops relaxed legacy layout" begin
    ops = @test_nowarn read_ops(legacy_file; relaxed=true, assume_scale_column=false, opf_scale=1.0, gwa_scale=0.01)
    @test length(children(ops)) == 2
    opfs = children(ops)
    @test opfs[1].scale == 1.0
    @test opfs[2].scale == 0.01
    @test opfs[1].functional_group == "coffee"
    @test opfs[2].functional_group == "pavement"
end

nogroup_file = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files", "scene_no_archimed.ops")
@testset "read_ops without Archimed header" begin
    ops = @test_nowarn read_ops(nogroup_file)
    @test length(children(ops)) == 1
    @test children(ops)[1].functional_group == ""
    @test_throws ErrorException read_ops(nogroup_file; require_functional_group=true)
end

@testset "read_ops forwards attribute_types to read_opf" begin
    files_dir = joinpath(pathof(PlantGeom) |> dirname |> dirname, "test", "files")
    mktempdir() do tmp
        cp(joinpath(files_dir, "simple_plant.opf"), joinpath(tmp, "simple_plant.opf"); force=true)

        ops_path = joinpath(tmp, "scene_attr_types.ops")
        open(ops_path, "w") do io
            println(io, "T 0.0 0.0 0.0 2.0 1.0 flat")
            println(io, "#[Archimed] plant")
            println(io, "1\t1\tsimple_plant.opf\t0.0\t0.0\t0.0\t1.0\t0.0\t0.0\t0.0")
        end

        scene = read_ops(ops_path; attribute_types=Dict("Length" => String))
        only_opf = only(children(scene))
        @test descendants(only_opf, :Length, ignore_nothing=true) == Any["0.1", "0.2", "0.1", "0.2"]
    end
end
