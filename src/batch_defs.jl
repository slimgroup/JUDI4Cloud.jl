
# Modeling
@batchdef function time_modeling_azure(_model, srcG, q, recG, D, _dm, op, mode, opt)
    model = fetch(_model)
    dm = isnothing(_dm) ? _dm : fetch(_dm)
    argout = time_modeling(model, srcG, q, recG, D, dm, op, mode, opt)
    return argout
end

#FWI
@batchdef function fwi_objective_azure(_model, q, D, opt)
    model = fetch(_model)
    argout = fwi_objective(model, q, D, opt)
    return argout
end

#LSRTM
@batchdef function lsrtm_objective_azure(_model, q, D, _dm, opt; nlind=false)
    model = fetch(_model)
    dm = isnothing(_dm) ? _dm : fetch(_dm)
    argout = lsrtm_objective(model,q, D, dm; options=opt, nlind=nlind)
    return argout
end

