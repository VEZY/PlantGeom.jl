@testset "reconstruction numeric alias contract" begin
    aliases = [:preferred, :alternate, :last]

    @testset "unavailable values continue in configured order" begin
        for null in (nothing, missing)
            @test PlantGeom._resolve_alias(
                Dict{Symbol,Any}(:preferred => null, :alternate => 2.5), aliases,
            ) == (2.5, :alternate)
            @test PlantGeom._resolve_alias(
                Dict{String,Any}("preferred" => null, "alternate" => "2.5"), aliases,
            ) == (2.5, :alternate)
            @test PlantGeom._resolve_alias(
                (preferred=null, alternate=2.5), aliases,
            ) == (2.5, :alternate)
        end
        @test PlantGeom._resolve_alias(
            Dict{Symbol,Any}(:preferred => nothing, :alternate => missing), aliases,
        ) === (nothing, nothing)
        @test PlantGeom._resolve_alias(Dict{Symbol,Any}(), aliases) === (nothing, nothing)

        # The mapping's order determines priority, rather than insertion order
        # in a dictionary. An unused lower-priority value is not inspected.
        node = Dict{Symbol,Any}(:alternate => 9.0, :preferred => 2.0, :last => "unused")
        @test PlantGeom._resolve_alias(node, aliases) == (2.0, :preferred)
        @test PlantGeom._resolve_alias(node, [:alternate, :preferred]) == (9.0, :alternate)
    end

    @testset "supplied invalid values are errors, not fallback requests" begin
        for invalid in ("not a number", :unknown, [2.0], Dict(:value => 2.0))
            node = Dict{Symbol,Any}(:preferred => invalid, :alternate => 2.5)
            error = try
                PlantGeom._resolve_alias(node, aliases)
                nothing
            catch exception
                exception
            end
            @test error isa ArgumentError
            if error isa ArgumentError
                @test occursin("preferred", sprint(showerror, error))
            end
            @test_throws ArgumentError PlantGeom._resolve_value(
                node, aliases, :length; default=1.0,
            )
        end
    end

    @testset "conversion and validation policies remain unchanged" begin
        for (raw, expected) in ((true, 1.0), (false, 0.0), ("2.5", 2.5),
                                (2.5u"cm", 2.5), (Inf, Inf), (NaN, NaN))
            @test isequal(
                PlantGeom._resolve_alias(Dict(:preferred => raw), aliases),
                (expected, :preferred),
            )
        end
        @test PlantGeom._resolve_value(
            Dict{Symbol,Any}(:preferred => nothing, :alternate => missing),
            aliases, :length; default=3.0,
        ) === 3.0

        # Boolean and text options have their own parsers. Numeric alias
        # validation does not change their accepted spellings or fallbacks.
        @test PlantGeom._resolve_bool_alias(
            Dict{Symbol,Any}(:preferred => missing, :alternate => "yes"), aliases,
        ) === true
        @test PlantGeom._resolve_bool_alias(
            Dict(:preferred => "unknown", :alternate => "yes"), aliases,
        ) === true
        @test PlantGeom._resolve_text_alias(
            Dict{Symbol,Any}(:preferred => nothing, :alternate => :CENTER), aliases,
        ) == ("CENTER", :alternate)
    end

    @testset "raw and structured numeric aliases" begin
        payload = (type=:cone, radius=2.0)
        @test PlantGeom._resolve_raw_alias(
            Dict{Symbol,Any}(:preferred => missing, :alternate => payload), aliases,
        ) == (payload, :alternate)
        @test PlantGeom._constraint_float_from_source(
            (radius=nothing, diameter=4.0), [:radius, :diameter],
        ) === 4.0
        @test PlantGeom._constraint_float_from_source(
            Dict{String,Any}("radius" => missing, "diameter" => "4.0"),
            [:radius, :diameter],
        ) === 4.0
        @test_throws ArgumentError PlantGeom._constraint_float_from_source(
            (radius="invalid", diameter=4.0), [:radius, :diameter],
        )
        @test PlantGeom._resolve_order_value(Dict(:Order => missing), :Order) === nothing
        @test PlantGeom._resolve_order_value(Dict(:Order => "3.6"), :Order) == 4
        @test_throws ArgumentError PlantGeom._resolve_order_value(Dict(:Order => "invalid"), :Order)
    end

    @testset "public size, angle, translation and pivot mappings" begin
        for null in (nothing, missing)
            node = Dict{Symbol,Any}(
                :Length => null, :length => 2.0,
                :Width => null, :width => 0.4,
                :Thickness => null, :thickness => 0.3,
                :ZEuler => null, :z_euler => 90.0,
                :XX => null, :xx => 3.0,
                :YY => null, :yy => 4.0,
                :ZZ => null, :zz => 5.0,
            )
            expected = Dict{Symbol,Any}(
                :Length => 2.0, :Width => 0.4, :Thickness => 0.3,
                :ZEuler => 90.0, :XX => 3.0, :YY => 4.0, :ZZ => 5.0,
            )
            actual_transform = transformation_from_attributes(node)
            expected_transform = transformation_from_attributes(expected)
            @test isequal(
                PlantGeom.transformation_matrix4(actual_transform),
                PlantGeom.transformation_matrix4(expected_transform),
            )
            @test actual_transform(SVector(0.0, 0.0, 0.0)) ≈ SVector(3.0, 4.0, 5.0)
        end
        for name in (:Length, :Width, :Thickness, :ZEuler, :XX, :YY, :ZZ)
            @test_throws ArgumentError transformation_from_attributes(Dict(name => "invalid"))
        end
        @test_throws ArgumentError PlantGeom._pivot_from_attributes(
            (:px, :py, :pz), Dict(:px => "invalid"); warn_missing=false,
        )
    end

    @testset "AMAP angle overrides validate supplied measurements" begin
        angle = PlantGeom.AngleConvention([:ZEuler, :z_euler], :z, :local, :deg, :origin)
        @test PlantGeom._resolve_angle_rad(
            Dict{Symbol,Any}(:ZEuler => nothing, :z_euler => 90.0), angle,
        ) == (pi / 2, true)
        @test PlantGeom._resolve_angle_rad(
            Dict{Symbol,Any}(:ZEuler => missing), angle;
            override_axis_deg=Dict(:z => 45.0), override_mode=:missing_only,
        ) == (pi / 4, true)
        @test_throws ArgumentError PlantGeom._resolve_angle_rad(
            Dict(:ZEuler => "invalid"), angle;
            override_axis_deg=Dict(:z => 45.0), override_mode=:override,
        )
    end

    @testset "columnar MTGs retain later aliases and do not mutate source values" begin
        scene = Node(NodeMTG(:/, :Scene, 1, 0))
        first_organ = Node(scene, NodeMTG(:/, :Internode, 1, 1))
        second_organ = Node(scene, NodeMTG(:/, :Internode, 2, 1))
        first_organ[:Length] = 1.0
        first_organ[:ZEuler] = nothing
        second_organ[:length] = 2.0
        second_organ[:zeuler] = 90.0
        before = [(node_id(node), repr(node_attributes(node))) for node in traverse(scene, identity)]
        @test PlantGeom._resolve_alias(second_organ, [:Length, :length]) == (2.0, :length)
        @test PlantGeom._resolve_alias(second_organ, [:ZEuler, :z_euler, :zeuler]) == (90.0, :zeuler)
        @test transformation_from_attributes(second_organ)(SVector(1.0, 0.0, 0.0)) ≈
              SVector(0.0, 1.0, 0.0) atol=1e-12
        @test [(node_id(node), repr(node_attributes(node))) for node in traverse(scene, identity)] == before
    end

    @testset "explicit endpoint aliases continue past unavailable columns" begin
        options = AmapReconstructionOptions()
        node = Dict{Symbol,Any}(
            :EndX => nothing, :end_x => 2.0,
            :EndY => missing, :end_y => 3.0,
            :EndZ => nothing, :end_z => 4.0,
        )
        @test PlantGeom._resolve_endpoint_position(node, options) == SVector(2.0, 3.0, 4.0)
        node[:EndX] = "invalid"
        @test_throws ArgumentError PlantGeom._resolve_endpoint_position(node, options)
        @test PlantGeom._resolve_endpoint_position(Dict(:EndX => 2.0), options) === nothing
    end

    @testset "public AMAP reconstruction uses later measured aliases" begin
        mesh = GeometryBasics.Mesh(
            [GeometryBasics.Point{3,Float64}(0.0, -0.1, 0.0),
             GeometryBasics.Point{3,Float64}(0.0, 0.1, 0.0),
             GeometryBasics.Point{3,Float64}(1.0, 0.0, 0.0)],
            [GeometryBasics.TriangleFace{Int}(1, 2, 3)],
        )
        prototypes = Dict("Internode" => RefMesh("alias contract", mesh))

        function reconstruct_alias_fixture(attributes, options)
            root = Node(NodeMTG(:/, :Plant, 1, 1))
            organ = Node(root, NodeMTG(:/, :Internode, 1, 2))
            for (name, value) in attributes
                organ[name] = value
            end
            reconstruct_geometry_from_attributes!(
                root, prototypes;
                convention=default_amap_geometry_convention(),
                amap_options=options, root_align=false,
            )
            return organ
        end

        for explicit_endpoints in (false, true)
            actual_attributes = Dict{Symbol,Any}(
                :Length => nothing, :length => 2.0,
                :Width => missing, :width => 0.2,
                :Thickness => nothing, :thickness => 0.1,
                :ZEuler => missing, :zeuler => 30.0,
                :XX => nothing, :xx => 1.0,
                :YY => missing, :yy => 2.0,
                :ZZ => nothing, :zz => 3.0,
            )
            canonical_attributes = Dict{Symbol,Any}(
                :Length => 2.0, :Width => 0.2, :Thickness => 0.1,
                :ZEuler => 30.0, :XX => 1.0, :YY => 2.0, :ZZ => 3.0,
            )
            if explicit_endpoints
                merge!(actual_attributes, Dict(
                    :EndX => nothing, :end_x => 4.0,
                    :EndY => missing, :end_y => 5.0,
                    :EndZ => nothing, :end_z => 6.0,
                ))
                merge!(canonical_attributes, Dict(:EndX => 4.0, :EndY => 5.0, :EndZ => 6.0))
            end
            options = AmapReconstructionOptions(
                explicit_coordinate_mode=explicit_endpoints ? :explicit_start_end_required : :topology_default,
            )
            actual = reconstruct_alias_fixture(actual_attributes, options)
            canonical = reconstruct_alias_fixture(canonical_attributes, options)
            actual_mesh = PlantGeom.refmesh_to_mesh(actual)
            canonical_mesh = PlantGeom.refmesh_to_mesh(canonical)
            @test isequal(
                PlantGeom.transformation_matrix4(actual[:geometry].transformation),
                PlantGeom.transformation_matrix4(canonical[:geometry].transformation),
            )
            @test isequal(collect(GeometryBasics.coordinates(actual_mesh)),
                          collect(GeometryBasics.coordinates(canonical_mesh)))
            @test isequal(collect(GeometryBasics.faces(actual_mesh)),
                          collect(GeometryBasics.faces(canonical_mesh)))
            @test actual[:ZEuler] === missing
            @test actual[:zeuler] === 30.0
        end
    end
end
