module NormalOrientationRegression

using Test, PlantGeom, GeometryBasics, StaticArrays, LinearAlgebra, Colors
import MultiScaleTreeGraph as MTG

const GB = GeometryBasics
const F = GB.TriangleFace{Int}
const P = GB.Point{3,Float64}
const I3 = Matrix{Float64}(I,3,3)
const MIRROR = Matrix(Diagonal([-1.0,1.0,1.0]))
const ROTATE = [0.0 -1.0 0.0; 1.0 0.0 0.0; 0.0 0.0 1.0]

points(mesh) = [Float64.(collect(p)) for p in GB.coordinates(mesh)]
faces(mesh) = [Tuple(Int.(collect(f))) for f in GB.faces(mesh)]
flip(fs) = [(f[1],f[3],f[2]) for f in fs]
affine(A,b=zeros(3)) = PlantGeom.Translation(b...) ∘ PlantGeom.LinearMap(A)
normal_vectors(ns) = eltype(ns)<:Real ? [Float64.(ns[i:i+2]) for i in 1:3:length(ns)] :
    [Float64.(collect(n)) for n in ns]

struct NonlinearLift <: PlantGeom.Transformation
    lift::Float64
end
(t::NonlinearLift)(p) = SVector(Float64(p[1]),Float64(p[2]),Float64(p[3])+t.lift*Float64(p[1])^2)

function metrics(mesh)
    ps,fs = points(mesh),faces(mesh)
    origin = reduce(+,ps)/length(ps)
    volume = 0.0; area = 0.0
    normals = Vector{Float64}[]
    edges = Dict{Tuple{Int,Int},Vector{Int}}()
    for f in fs
        a,b,c = ps[collect(f)]
        raw = cross(b-a,c-a)
        push!(normals,iszero(norm(raw)) ? zeros(3) : raw/norm(raw))
        area += norm(raw)/2
        volume += dot(a-origin,cross(b-origin,c-origin))/6
        for (u,v) in ((f[1],f[2]),(f[2],f[3]),(f[3],f[1]))
            push!(get!(edges,minmax(u,v),Int[]),u<v ? 1 : -1)
        end
    end
    return (;volume,area,normals,
        closed=all(v->length(v)==2 && sum(v)==0,values(edges)))
end

function tetrahedron()
    # Independently authored outward faces: -Z, -Y, -X, then +(1,1,1).
    GB.Mesh(P.([(0.,0.,0.),(1.,0.,0.),(0.,1.,0.),(0.,0.,1.)]),
        F.([(1,3,2),(1,2,4),(1,4,3),(2,3,4)]))
end

function source(kind,ref; transformation=PlantGeom.IdentityTransformation())
    kind === :static && return PlantGeom.Geometry(;ref_mesh=ref,transformation)
    kind === :pointmapped && return PlantGeom.PointMappedGeometry(ref,identity;transformation)
    return PlantGeom.ExtrudedTubeGeometry([(0.,0.,0.),(2.,0.,0.)];
        radius=.5,n_sides=8,cap_ends=true,transformation)
end

@testset "Known affine materialization preserves outward orientation" begin
    ref = RefMesh("outward-tetrahedron",tetrahedron())
    original_points,original_faces = points(ref.mesh),faces(ref.mesh)
    original_normals = deepcopy(ref.normals)
    transforms = (("identity",I3),("rotation",ROTATE),
        ("nonuniform",Matrix(Diagonal([2.,3.,4.]))),
        ("reflection",Matrix(Diagonal([-2.,3.,4.]))),
        ("two reflections",MIRROR*MIRROR))
    for kind in (:static,:pointmapped,:tube)
        reference = PlantGeom.geometry_to_mesh(source(kind,ref))
        refstats = metrics(reference)
        analytic_volume = kind === :tube ? 8sin(2pi/8)*.5^2*2/2 : 1/6
        @test refstats.volume ≈ analytic_volume atol=1e-12
        @test refstats.closed
        for (name,A) in transforms
            @testset "$kind / $name" begin
                offset = [1.25,-2.5,.75]
                observed = PlantGeom.geometry_to_mesh(source(kind,ref;transformation=affine(A,offset)))
                obs = metrics(observed)
                @test all(isapprox(a,b;atol=1e-12) for (a,b) in zip(points(observed),[A*p+offset for p in points(reference)]))
                @test faces(observed) == (det(A)<0 ? flip(faces(reference)) : faces(reference))
                @test obs.volume > 0
                @test obs.volume ≈ abs(det(A))*analytic_volume atol=1e-11
                @test obs.closed
                expected_normals = [normalize(transpose(A)\n) for n in refstats.normals]
                @test all(isapprox(a,b;atol=1e-12) for (a,b) in zip(obs.normals,expected_normals))
            end
        end
    end
    @test points(ref.mesh)==original_points
    @test faces(ref.mesh)==original_faces
    @test ref.normals==original_normals
end

@testset "Affine point maps and outer reflections compose" begin
    ref = RefMesh("mapped-tetrahedron",tetrahedron())
    reflected = PlantGeom.geometry_to_mesh(PlantGeom.PointMappedGeometry(ref,PlantGeom.LinearMap(MIRROR)))
    @test faces(reflected)==flip(faces(ref.mesh))
    @test points(reflected)==[MIRROR*p for p in points(ref.mesh)]
    @test metrics(reflected).volume ≈ 1/6
    for maps in ((identity,PlantGeom.LinearMap(MIRROR)),
        (PlantGeom.LinearMap(MIRROR),identity))
        composed = PlantGeom.geometry_to_mesh(PlantGeom.PointMappedGeometry(ref,
            PlantGeom.compose_point_maps(maps...)))
        @test faces(composed)==faces(reflected)
        @test points(composed)==points(reflected)
    end
    twice = PlantGeom.geometry_to_mesh(PlantGeom.PointMappedGeometry(ref,
        PlantGeom.LinearMap(MIRROR);transformation=PlantGeom.LinearMap(MIRROR)))
    @test points(twice)==points(ref.mesh)
    @test faces(twice)==faces(ref.mesh)
    @test metrics(twice).volume ≈ 1/6
end

@testset "Nonlinear orientation is explicit and callbacks run once per vertex" begin
    ref = RefMesh("declared-map",tetrahedron())
    count = Ref(0)
    mapping = p -> begin
        count[] += 1
        SVector(-p[1],p[2],p[3]+.25p[1]^2)
    end
    declared = PlantGeom.OrientedPointMap(mapping;orientation=-1)
    result = PlantGeom.geometry_to_mesh(PlantGeom.PointMappedGeometry(ref,declared;params=:unused))
    @test count[]==4
    @test faces(result)==flip(faces(ref.mesh))
    @test points(result)==[[-p[1],p[2],p[3]+.25p[1]^2] for p in points(ref.mesh)]
    @test metrics(result).volume ≈ 1/6
    count[] = 0
    twice = PlantGeom.geometry_to_mesh(PlantGeom.PointMappedGeometry(ref,declared;
        transformation=PlantGeom.LinearMap(MIRROR)))
    @test count[]==4
    @test faces(twice)==faces(ref.mesh)
    @test metrics(twice).volume ≈ 1/6
    count[] = 0
    opaque = PlantGeom.geometry_to_mesh(PlantGeom.PointMappedGeometry(ref,mapping))
    @test count[]==4
    # Arbitrary callables retain authored indexing unless they declare a
    # constant orientation. A globally folded map cannot be repaired this way.
    @test faces(opaque)==faces(ref.mesh)
    @test metrics(opaque).volume ≈ -1/6
    param_calls = Ref(0)
    param_map = (p,parameters) -> begin
        param_calls[] += 1
        SVector(p[1],p[2],p[3]+parameters.lift*p[1]^2)
    end
    positive = PlantGeom.geometry_to_mesh(PlantGeom.PointMappedGeometry(ref,
        PlantGeom.OrientedPointMap(param_map;orientation=1);params=(lift=.5,)))
    @test param_calls[]==4
    @test faces(positive)==faces(ref.mesh)
    @test points(positive)==[[p[1],p[2],p[3]+.5p[1]^2] for p in points(ref.mesh)]
    @test metrics(positive).volume ≈ 1/6
    @test_throws ArgumentError PlantGeom.OrientedPointMap(identity;orientation=0)
    @test_throws ArgumentError PlantGeom.OrientedPointMap(identity;orientation=2)
end

@testset "Scene merge retains corrected faces and botanical owners" begin
    tree = MTG.Node(MTG.NodeMTG(:/,:Plant,1,1))
    ref = RefMesh("shared-outward",tetrahedron())
    nodes = [MTG.Node(tree,MTG.NodeMTG(:/,:Internode,i,2)) for i in 1:3]
    expected_meshes = Any[]
    for (i,(node,kind)) in enumerate(zip(nodes,(:static,:pointmapped,:tube)))
        node[:geometry] = source(kind,ref;transformation=affine(MIRROR,[3.0i,0.,0.]))
        push!(expected_meshes,PlantGeom.geometry_to_mesh(node[:geometry]))
    end
    merged,owners = PlantGeom.build_merged_mesh_with_map(tree)
    @test length(owners)==length(faces(merged))
    @test unique(owners)==Int.(MTG.node_id.(nodes))
    offset = 0
    for (node,expected) in zip(nodes,expected_meshes)
        selected = findall(==(MTG.node_id(node)),owners)
        @test faces(merged)[selected]==[Tuple(i+offset for i in f) for f in faces(expected)]
        @test points(merged)[offset+1:offset+length(points(expected))]==points(expected)
        offset += length(points(expected))
    end
    @test metrics(merged).closed
    @test metrics(merged).volume > 0
    @test faces(ref.mesh)==faces(tetrahedron())
end

@testset "Stored RefMesh normals transform without replacing authored data" begin
    mesh = GB.Mesh(P.([(0.,0.,0.),(1.,0.,0.),(1.,1.,0.),(0.,1.,0.)]),F.([(1,2,3),(1,3,4)]))
    uv = [(0.,0.),(1.,0.),(1.,1.),(0.,1.)]
    saved_uv = deepcopy(uv)
    saved_points,saved_faces = points(mesh),faces(mesh)
    material = RGB(.21,.43,.65)
    # Deliberately authored smooth normals differ from geometric +Z: replacing
    # them with triangle normals would erase valid input information.
    authored = [normalize([1.,2.,3.]),normalize([3.,-2.,1.]),normalize([-1.,3.,2.]),normalize([2.,1.,4.])]
    for layout in (:vertex,:face), storage in (:float64,:float32,:tuple,:flat)
        ns = authored[1:(layout === :vertex ? 4 : 2)]
        normals = storage === :flat ? reduce(vcat,ns) : storage === :tuple ? Tuple.(ns) :
            storage === :float32 ? GB.Vec{3,Float32}.(ns) : GB.Vec{3,Float64}.(ns)
        ref = RefMesh("authored-$layout-$storage",mesh,normals,uv,material,true)
        saved_normals = deepcopy(ref.normals)
        for A in (ROTATE,Matrix(Diagonal([2.,3.,4.])),Matrix(Diagonal([-2.,3.,4.])))
            moved = PlantGeom.apply(affine(A,[4.,5.,6.]),ref)
            expected = [normalize(transpose(A)\n) for n in normal_vectors(normals)]
            observed = normal_vectors(moved.normals)
            tolerance = storage === :float32 ? 2eps(Float32) : 1e-12
            @test length(moved.normals)==length(normals)
            @test (eltype(moved.normals)<:Real)==(storage === :flat)
            @test all(isapprox(a,b;atol=tolerance) for (a,b) in zip(observed,expected))
            @test all(n->isapprox(norm(n),1.;atol=tolerance),observed)
            @test all(isapprox(a,b;atol=1e-12) for (a,b) in zip(points(moved.mesh),[A*p+[4.,5.,6.] for p in saved_points]))
            @test faces(moved.mesh)==(det(A)<0 ? flip(faces(mesh)) : faces(mesh))
            @test moved.texture_coords==saved_uv
            @test moved.material==material
            @test moved.taper===true
        end
        twice = PlantGeom.apply(PlantGeom.LinearMap(MIRROR),PlantGeom.apply(PlantGeom.LinearMap(MIRROR),ref))
        @test faces(twice.mesh)==faces(mesh)
        @test points(twice.mesh)==points(mesh)
        @test all(isapprox(a,b;atol=2eps(Float32)) for (a,b) in zip(normal_vectors(twice.normals),normal_vectors(normals)))
        @test ref.normals==saved_normals
        @test ref.texture_coords==saved_uv
        @test faces(ref.mesh)==saved_faces
        @test points(ref.mesh)==saved_points
    end
end

@testset "Empty and singular normal data remain explicit and finite" begin
    mesh = tetrahedron()
    ref = RefMesh("no-stored-normals",mesh,GB.Vec{3,Float64}[],nothing,RGB(.2,.4,.6),false)
    moved = PlantGeom.apply(PlantGeom.LinearMap(MIRROR),ref)
    @test isempty(moved.normals)
    @test isempty(ref.normals)
    @test faces(moved.mesh)==flip(faces(mesh))
    @test PlantGeom.normals_vertex(moved.mesh)==PlantGeom.normals_vertex(moved)
    stored = RefMesh("collapsed",mesh,[GB.Vec{3,Float64}(0.,0.,1.) for _ in 1:4],nothing,ref.material,false)
    collapsed = PlantGeom.apply(PlantGeom.LinearMap(zeros(3,3)),stored)
    @test all(p->all(isfinite,p),points(collapsed.mesh))
    @test all(n->all(isfinite,n),collapsed.normals)
    @test all(n->all(iszero,n),collapsed.normals)
    @test metrics(collapsed.mesh).area==0
    @test metrics(collapsed.mesh).volume==0
    @test faces(collapsed.mesh)==faces(mesh)
    @test all(n->n==GB.Vec{3,Float64}(0.,0.,1.),stored.normals)
    # A rank-two map still has a meaningful transported normal for its
    # noncollapsed plane; using an inverse would fail unnecessarily here.
    planar = PlantGeom.apply(PlantGeom.LinearMap(Matrix(Diagonal([2.,3.,0.]))),stored)
    @test all(n->n≈[0.,0.,1.],normal_vectors(planar.normals))
    @test all(p->all(isfinite,p),points(planar.mesh))
end

@testset "Unknown nonlinear transformations recompute associated normals" begin
    mesh = GB.Mesh(P.([(0.,0.,0.),(1.,0.,0.),(1.,1.,0.),(0.,1.,0.)]),F.([(1,2,3),(1,3,4)]))
    expected = normalize([-.25,0.,1.]) # independent normal of the transformed chords
    for count in (2,4)
        normals = [GB.Vec{3,Float64}(0.,0.,1.) for _ in 1:count]
        ref = RefMesh("unknown-map-$count",mesh,normals,nothing,RGB(.2,.4,.6),false)
        result = PlantGeom.apply(NonlinearLift(.25),ref)
        @test length(result.normals)==count
        @test all(n->isapprox(n,expected;atol=1e-12),normal_vectors(result.normals))
        @test faces(result.mesh)==faces(mesh)
        @test all(n->n==GB.Vec{3,Float64}(0.,0.,1.),ref.normals)
    end
    invalid = RefMesh("unknown-association",mesh,[GB.Vec{3,Float64}(0.,0.,1.) for _ in 1:3],nothing,RGB(.2,.4,.6),false)
    @test_throws ArgumentError PlantGeom.apply(NonlinearLift(.25),invalid)
end

@testset "Extreme anisotropy retains small but meaningful normal directions" begin
    ns = GB.Vec{3,Float64}.([[1.,0.,0.],normalize([1.,1e-200,1.]),[0.,1.,0.],[0.,0.,1.]])
    ref = RefMesh("extreme",tetrahedron(),ns,nothing,RGB(.2,.4,.6),false)
    saved_normals = deepcopy(ns)
    for sign in (-1.,1.)
        A = Matrix(Diagonal([sign*1e200,1e-200,1.]))
        moved = PlantGeom.apply(PlantGeom.LinearMap(A),ref)
        @test normal_vectors(moved.normals)[1] ≈ [sign,0.,0.] atol=1e-12
        @test normal_vectors(moved.normals)[2] ≈ normalize([sign*1e-200,1.,1.]) atol=1e-12
        @test all(n->all(isfinite,n),normal_vectors(moved.normals))
        @test PlantGeom._affine_orientation_parity(PlantGeom.LinearMap(A))==Int(sign)
    end
    @test ref.normals==saved_normals
end

@testset "Prototype unit normalization transports authored normals" begin
    mesh = GB.Mesh(P.([2 .* p .* [1.,2.,3.] .+ [1.,2.,3.] for p in points(tetrahedron())]),F.(faces(tetrahedron())))
    ns = [GB.Vec{3,Float64}(normalize([1.,2.,3.])) for _ in 1:4]
    ref = RefMesh("anisotropic-prototype",mesh,ns,nothing,RGB(.2,.4,.6),true)
    before,saved_normals = points(ref.mesh),deepcopy(ns)
    normalized,already_unit = PlantGeom._normalize_ref_mesh_to_unit(ref;warn=false)
    @test !already_unit
    @test all(n->isapprox(n,normalize([2.,8.,18.]);atol=1e-12),normal_vectors(normalized.normals))
    @test faces(normalized.mesh)==faces(mesh)
    @test normalized.taper && normalized.material==ref.material
    @test points(ref.mesh)==before && ref.normals==saved_normals
end

end # module
