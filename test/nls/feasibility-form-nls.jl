@testset "FeasibilityFormNLS tests" begin
  @testset "NLS API" begin
    F(x) = [x[3]; x[4]]
    JF(x) = Float64[0 0 1 0; 0 0 0 1]
    HF(x,w) = zeros(4, 4)

    nls = FeasibilityFormNLS(SimpleNLSModel())
    n = nls.meta.nvar
    m = nls.meta.ncon
    ne = nls_meta(nls).nequ

    x = randn(n)
    v = randn(n)
    w = randn(ne)
    Jv = zeros(ne)
    Jtw = zeros(n)
    Hv = zeros(n)

    @test residual(nls, x) ≈ F(x)
    @test jac_residual(nls, x) ≈ JF(x)
    @test hess_residual(nls, x, w) ≈ HF(x, w)
    @test jprod_residual(nls, x, v) ≈ JF(x) * v
    @test jtprod_residual(nls, x, w) ≈ JF(x)' * w
    @test jprod_residual!(nls, jac_structure_residual(nls)..., jac_coord_residual(nls, x), v, Jv) ≈ JF(x) * v
    @test jtprod_residual!(nls, jac_structure_residual(nls)..., jac_coord_residual(nls, x), w, Jtw) ≈ JF(x)' * w
    @test jprod_residual!(nls, x, jac_structure_residual(nls)..., v, Jv) ≈ JF(x) * v
    @test jtprod_residual!(nls, x, jac_structure_residual(nls)..., w, Jtw) ≈ JF(x)' * w
    Jop = jac_op_residual(nls, x)
    @test Jop * v ≈ JF(x) * v
    @test Jop' * w ≈ JF(x)' * w
    Jop = jac_op_residual!(nls, x, Jv, Jtw)
    @test Jop * v ≈ JF(x) * v
    @test Jop' * w ≈ JF(x)' * w
    Jop = jac_op_residual!(nls, jac_structure_residual(nls)..., jac_coord_residual(nls, x), Jv, Jtw)
    @test Jop * v ≈ JF(x) * v
    @test Jop' * w ≈ JF(x)' * w
    Jop = jac_op_residual!(nls, x, jac_structure_residual(nls)..., Jv, Jtw)
    @test Jop * v ≈ JF(x) * v
    @test Jop' * w ≈ JF(x)' * w
    I, J, V = findnz(sparse(HF(x, w)))
    @test hess_structure_residual(nls) == (I, J)
    @test hess_coord_residual(nls, x, w) ≈ V
    for j = 1:ne
      eⱼ = [i == j ? 1.0 : 0.0 for i = 1:ne]
      @test jth_hess_residual(nls, x, j) ≈ HF(x, eⱼ)
      @test hprod_residual(nls, x, j, v) ≈ HF(x, eⱼ) * v
      Hop = hess_op_residual(nls, x, j)
      @test Hop * v ≈ HF(x, eⱼ) * v
      Hop = hess_op_residual!(nls, x, j, Hv)
      @test Hop * v ≈ HF(x, eⱼ) * v
    end
  end

  @testset "NLP API" begin
    F(x) = [x[3]; x[4]]
    JF(x) = Float64[0 0 1 0; 0 0 0 1]
    HF(x,w) = zeros(4, 4)
    f(x) = norm(F(x))^2 / 2
    ∇f(x) = JF(x)' * F(x)
    H(x) = JF(x)' * JF(x) + HF(x, F(x))
    c(x) = [1 - x[1] - x[3]; 10 * (x[2] - x[1]^2) - x[4]; x[1] + x[2]^2; x[1]^2 + x[2]; x[1]^2 + x[2]^2 - 1]
    J(x) = [-1 0 -1 0; -20x[1] 10 0 -1; 1 2x[2] 0 0; 2x[1] 1 0 0; 2x[1] 2x[2] 0 0]
    H(x,y) = H(x) + diagm(0 => [-20y[2] + 2y[4] + 2y[5]; 2y[3] + 2y[5]; 0; 0])

    nls = FeasibilityFormNLS(SimpleNLSModel())
    n = nls.meta.nvar
    m = nls.meta.ncon

    x = randn(n)
    y = randn(m)
    v = randn(n)
    w = randn(m)
    Jv = zeros(m)
    Jtw = zeros(n)
    Hv = zeros(n)
    Hvals = zeros(nls.meta.nnzh)

    fx, gx = objgrad!(nls, x, v)
    @test obj(nls, x) ≈ norm(F(x))^2 / 2 ≈ fx ≈ f(x)
    @test grad(nls, x) ≈ JF(x)' * F(x) ≈ gx ≈ ∇f(x)
    @test hess(nls, x) ≈ tril(H(x))
    @test hprod(nls, x, v) ≈ H(x) * v
    @test cons(nls, x) ≈ c(x)
    @test jac(nls, x) ≈ J(x)
    @test jprod(nls, x, v) ≈ J(x) * v
    @test jtprod(nls, x, w) ≈ J(x)' * w
    @test hess(nls, x, y) ≈ tril(H(x,y))
    @test hprod(nls, x, y, v) ≈ H(x, y) * v
    fx, cx = objcons(nls, x)
    @test fx ≈ f(x)
    @test cx ≈ c(x)
    fx, _ = objcons!(nls, x, cx)
    @test fx ≈ f(x)
    @test cx ≈ c(x)
    fx, gx = objgrad(nls, x)
    @test fx ≈ f(x)
    @test gx ≈ ∇f(x)
    fx, _ = objgrad!(nls, x, gx)
    @test fx ≈ f(x)
    @test gx ≈ ∇f(x)
    @test jprod!(nls, jac_structure(nls)..., jac_coord(nls, x), v, Jv) ≈ J(x) * v
    @test jprod!(nls, x, jac_structure(nls)..., v, Jv) ≈ J(x) * v
    @test jtprod!(nls, jac_structure(nls)..., jac_coord(nls, x), w, Jtw) ≈ J(x)' * w
    @test jtprod!(nls, x, jac_structure(nls)..., w, Jtw) ≈ J(x)' * w
    Jop = jac_op!(nls, x, Jv, Jtw)
    @test Jop * v ≈ J(x) * v
    @test Jop' * w ≈ J(x)' * w
    Jop = jac_op!(nls, jac_structure(nls)..., jac_coord(nls, x), Jv, Jtw)
    @test Jop * v ≈ J(x) * v
    @test Jop' * w ≈ J(x)' * w
    Jop = jac_op!(nls, x, jac_structure(nls)..., Jv, Jtw)
    @test Jop * v ≈ J(x) * v
    @test Jop' * w ≈ J(x)' * w
    ghjv = zeros(m)
    for j = 1:m
      eⱼ = [i == j ? 1.0 : 0.0 for i = 1:m]
      Cⱼ(x) = H(x, eⱼ) - H(x)
      ghjv[j] = dot(gx, Cⱼ(x) * v)
    end
    @test ghjvprod(nls, x, gx, v) ≈ ghjv
    @test hess_coord!(nls, x, Hvals) == hess_coord!(nls, x, y * 0, Hvals)
    @test hprod!(nls, hess_structure(nls)..., hess_coord(nls, x), v, Hv) ≈ H(x) * v
    @test hprod!(nls, x, hess_structure(nls)..., v, Hv) ≈ H(x) * v
    @test hprod!(nls, x, y, hess_structure(nls)..., v, Hv) ≈ H(x, y) * v
    Hop = hess_op(nls, x)
    @test Hop * v ≈ H(x) * v
    Hop = hess_op!(nls, x, Hv)
    @test Hop * v ≈ H(x) * v
    Hop = hess_op!(nls, hess_structure(nls)..., hess_coord(nls, x), Hv)
    @test Hop * v ≈ H(x) * v
    Hop = hess_op!(nls, x, hess_structure(nls)..., Hv)
    @test Hop * v ≈ H(x) * v
    Hop = hess_op(nls, x, y)
    @test Hop * v ≈ H(x, y) * v
    Hop = hess_op!(nls, x, y, Hv)
    @test Hop * v ≈ H(x, y) * v
    Hop = hess_op!(nls, hess_structure(nls)..., hess_coord(nls, x, y), Hv)
    @test Hop * v ≈ H(x, y) * v
    Hop = hess_op!(nls, x, y, hess_structure(nls)..., Hv)
    @test Hop * v ≈ H(x, y) * v
  end

  @testset "Show" begin
    nls = FeasibilityFormNLS(SimpleNLSModel())
    io = IOBuffer()
    show(io, nls)
    showed = String(take!(io))
    expected = """FeasibilityFormNLS - Nonlinear least-squares moving the residual to constraints
    Problem name: Simple NLS Model-ffnls
     All variables: ████████████████████ 4      All constraints: ████████████████████ 5        All residuals: ████████████████████ 2
              free: ██████████⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 2                 free: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0               linear: ████████████████████ 2
             lower: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                lower: ████████⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 2            nonlinear: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0
             upper: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                upper: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                 nnzj: ( 75.00% sparsity)   2
           low/upp: ██████████⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 2              low/upp: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                 nnzh: (100.00% sparsity)   0
             fixed: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                fixed: ████████████⋅⋅⋅⋅⋅⋅⋅⋅ 3
            infeas: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0               infeas: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0
              nnzh: ( 40.00% sparsity)   6               linear: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0
                                                      nonlinear: ████████████████████ 5
                                                           nnzj: ( 45.00% sparsity)   11

    Counters:
               obj: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                 grad: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                 cons: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0
              jcon: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                jgrad: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                  jac: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0
             jprod: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0               jtprod: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0                 hess: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0
             hprod: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0               jhprod: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0             residual: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0
      jac_residual: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0       jprod_residual: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0      jtprod_residual: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0
     hess_residual: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0       jhess_residual: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0       hprod_residual: ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅ 0"""

    @test strip.(split(chomp(showed), "\n")) == strip.(split(chomp(expected), "\n"))
  end

  @testset "FeasibilityFormNLS of a FeasibilityResidual" begin
    nlp = SimpleNLPModel()
    snlp = SlackModel(nlp)
    nls = FeasibilityResidual(nlp)
    fnlp = FeasibilityFormNLS(nls)

    @test fnlp.meta.nnzj == snlp.meta.nnzj + snlp.meta.ncon
    @test fnlp.meta.nnzh == snlp.meta.nnzh + snlp.meta.ncon
  end
end