module TransformationMatrixFixtures
using PlantGeom
using StaticArrays: SVector

const CT = PlantGeom.CoordinateTransformations

struct DerivativeProbe{D} <: PlantGeom.Transformation
    linear::Matrix{Float64}
    offset::SVector{3,Float64}
    derivative::D
    evaluations::Base.RefValue{Int}
end

function (transformation::DerivativeProbe)(point)
    transformation.evaluations[] += 1
    return transformation.linear * point + transformation.offset
end

CT.transform_deriv(transformation::DerivativeProbe, _point) = transformation.derivative

struct NoDerivative <: PlantGeom.Transformation
    evaluations::Base.RefValue{Int}
end

function (transformation::NoDerivative)(point)
    transformation.evaluations[] += 1
    return SVector(point[1] + point[1]^2, point[2] + point[2] * point[3], point[3])
end
end

@testset "transformation matrices preserve derivative and fallback contracts" begin
    fixtures = TransformationMatrixFixtures
    offset = SVector(0.25, -0.5, 0.75)

    function expected_matrix(linear, translation)
        matrix = Matrix{Float64}(I, 4, 4)
        matrix[1:3, 1:3] = linear
        matrix[1:3, 4] = translation
        return matrix
    end

    @testset "uniform derivatives avoid basis-vector evaluation" begin
        @test isequal(
            PlantGeom.transformation_matrix4(PlantGeom.IdentityTransformation()),
            Matrix{Float64}(I, 4, 4),
        )
        @test isequal(
            PlantGeom.transformation_matrix4(PlantGeom.Translation(offset)),
            expected_matrix(Matrix{Float64}(I, 3, 3), offset),
        )

        for multiplier in (1.0, 2.5, 0.0)
            linear = Matrix{Float64}(multiplier * I, 3, 3)
            probe = fixtures.DerivativeProbe(linear, offset, multiplier * I, Ref(0))
            @test isequal(
                PlantGeom.transformation_matrix4(probe),
                expected_matrix(linear, offset),
            )
            # A valid UniformScaling derivative is sufficient: only the origin
            # is evaluated for translation, with no exception-driven probing.
            @test probe.evaluations[] == 1
        end

        # Subtracting nearby transformed basis vectors loses the linear part
        # at this magnitude; the supplied exact identity derivative does not.
        distant_offset = SVector(2.0^54, -2.0^54, 2.0^54)
        @test isequal(
            PlantGeom.transformation_matrix4(PlantGeom.Translation(distant_offset)),
            expected_matrix(Matrix{Float64}(I, 3, 3), distant_offset),
        )
    end

    @testset "general affine derivatives remain unchanged" begin
        linear = [2.0 0.5 -0.25; -1.0 3.0 0.75; 0.0 0.25 0.5]
        affine = PlantGeom.AffineMap(linear, offset)
        @test isequal(
            PlantGeom.transformation_matrix4(affine),
            expected_matrix(linear, offset),
        )
        probe = fixtures.DerivativeProbe(linear, offset, linear, Ref(0))
        @test isequal(
            PlantGeom.transformation_matrix4(probe),
            expected_matrix(linear, offset),
        )
        @test probe.evaluations[] == 1
    end

    @testset "unusable derivatives retain the basis-vector fallback" begin
        linear = [2.0 0.5 -0.25; -1.0 3.0 0.75; 0.0 0.25 0.5]
        for derivative in (nothing, ones(2, 2), fill(NaN, 3, 3), Inf * I)
            probe = fixtures.DerivativeProbe(linear, offset, derivative, Ref(0))
            @test isequal(
                PlantGeom.transformation_matrix4(probe),
                expected_matrix(linear, offset),
            )
            @test probe.evaluations[] == 4
        end

        nonlinear = fixtures.NoDerivative(Ref(0))
        # For an unsupported nonlinear derivative, retain the existing matrix
        # defined by the origin and three unit-basis evaluations.
        @test isequal(
            PlantGeom.transformation_matrix4(nonlinear),
            expected_matrix(Diagonal([2.0, 1.0, 1.0]), zeros(3)),
        )
        @test nonlinear.evaluations[] == 4
    end
end
