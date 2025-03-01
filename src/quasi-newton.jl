export QuasiNewtonModel, LBFGSModel, LSR1Model

abstract type QuasiNewtonModel <: AbstractNLPModel end

mutable struct LBFGSModel <: QuasiNewtonModel
  meta :: NLPModelMeta
  model :: AbstractNLPModel
  op :: LBFGSOperator
end

mutable struct LSR1Model <: QuasiNewtonModel
  meta :: NLPModelMeta
  model :: AbstractNLPModel
  op :: LSR1Operator
end

"Construct a `LBFGSModel` from another type of model."
function LBFGSModel(nlp :: AbstractNLPModel; kwargs...)
  op = LBFGSOperator(nlp.meta.nvar; kwargs...)
  return LBFGSModel(nlp.meta, nlp, op)
end

"Construct a `LSR1Model` from another type of nlp."
function LSR1Model(nlp :: AbstractNLPModel; kwargs...)
  op = LSR1Operator(nlp.meta.nvar; kwargs...)
  return LSR1Model(nlp.meta, nlp, op)
end

NLPModels.show_header(io :: IO, nlp :: QuasiNewtonModel) = println(io, "$(typeof(nlp)) - A QuasiNewtonModel")

function Base.show(io :: IO, nlp :: QuasiNewtonModel)
  show_header(io, nlp)
  show(io, nlp.meta)
  show(io, nlp.model.counters)
end

@default_counters QuasiNewtonModel model

function NLPModels.reset_data!(nlp :: QuasiNewtonModel)
  reset!(nlp.op)
  return nlp
end

# the following methods are not affected by the Hessian approximation
for meth in (:obj, :grad, :cons, :jac_coord, :jac)
  @eval NLPModels.$meth(nlp :: QuasiNewtonModel, x :: AbstractVector) = $meth(nlp.model, x)
end
for meth in (:grad!, :cons!, :jprod, :jtprod, :objgrad, :objgrad!, :jac_coord!)
  @eval NLPModels.$meth(nlp :: QuasiNewtonModel, x :: AbstractVector, y :: AbstractVector) = $meth(nlp.model, x, y)
end
for meth in (:jprod!, :jtprod!)
  @eval NLPModels.$meth(nlp :: QuasiNewtonModel, x :: AbstractVector, y :: AbstractVector, z :: AbstractVector) = $meth(nlp.model, x, y, z)
end
NLPModels.jac_structure!(nlp :: QuasiNewtonModel, rows :: AbstractVector{<: Integer}, cols :: AbstractVector{<: Integer}) = jac_structure!(nlp.model, rows, cols)

# the following methods are affected by the Hessian approximation
NLPModels.hess_op(nlp :: QuasiNewtonModel, x :: AbstractVector; kwargs...) = nlp.op
NLPModels.hprod(nlp :: QuasiNewtonModel, x :: AbstractVector, v :: AbstractVector; kwargs...) = nlp.op * v
function NLPModels.hprod!(nlp :: QuasiNewtonModel, x :: AbstractVector,
                v :: AbstractVector, Hv :: AbstractVector; kwargs...)
  Hv[1:nlp.meta.nvar] .= nlp.op * v
  return Hv
end

function Base.push!(nlp :: QuasiNewtonModel, args...)
	push!(nlp.op, args...)
	return nlp
end

# not implemented: hess_structure, hess_coord, hess, ghjvprod
