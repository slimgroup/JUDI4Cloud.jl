
####### Single source per instance ##################
# Modeling
@batchdef function time_modeling_azure(_model::BatchFuture, srcG, q, recG, D, _dm, op, mode, opt)
    check_njulia(q, D)
    model = fetch(_model)
    dm = isnothing(_dm) ? _dm : fetch(_dm)
    argout = time_modeling(model, srcG, q, recG, D, dm, op, mode, opt)
    rmprocs(workers())
    return argout
end

#FWI
@batchdef function fwi_objective_azure(_model::BatchFuture, q, D, opt)
    check_njulia(q, D)
    model = fetch(_model)
    argout = fwi_objective(model, q, D; options=opt)
    rmprocs(workers())
    return argout
end

#LSRTM
@batchdef function lsrtm_objective_azure(_model::BatchFuture, q, D, _dm, opt; nlind=false)
    check_njulia(q, D)
    model = fetch(_model)
    dm = isnothing(_dm) ? _dm : fetch(_dm)
    argout = lsrtm_objective(model,q, D, dm; options=opt, nlind=nlind)
    rmprocs(workers())
    return argout
end


check_njulia(q::judiVector, ::judiVector) = check_njulia(q.nsrc)
check_njulia(q, D::Nothing) = check_njulia(D, q)
check_njulia(q::Nothing, D) = check_njulia(length(D))

function check_njulia(nsrc::Integer)
    if _njpi == 1 || nsrc == 1
        return
    end
    nw = nsrc >= _njpi ? _njpi : nsrc
    @info "Starting julia distributed with $(nw) workers"
    addprocs(nw)
end