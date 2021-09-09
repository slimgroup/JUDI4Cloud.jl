
####### Single source per instance ##################
# Modeling
@batchdef function time_modeling_azure(_model::BatchFuture, srcG, q, recG, D, _dm, op, mode, opt)
    nsrc = isnothing(srcG) ? length(recG.xloc) : length(srcG.xloc)
    check_njulia(nsrc)
    model = fetch(_model)
    dm = isnothing(_dm) ? _dm : fetch(_dm)
    if nsrc > 1
        argout = time_modeling(model, srcG, q, recG, D, dm, 1:nsrc, op, mode, opt)
    else
        argout = time_modeling(model, srcG, q, recG, D, dm, op, mode, opt)
    end
    rmprocs(workers())
    return argout
end

#FWI
@batchdef function fwi_objective_azure(_model::BatchFuture, q, D, opt)
    check_njulia(q.nsrc)
    model = fetch(_model)
    f, g = fwi_objective(model, q, D; options=opt)
    rmprocs(workers())
    return f, g
end

#LSRTM
@batchdef function lsrtm_objective_azure(_model::BatchFuture, q, D, _dm, opt; nlind=false)
    check_njulia(q.nsrc)
    model = fetch(_model)
    dm = isnothing(_dm) ? _dm : fetch(_dm)
    f, g = lsrtm_objective(model,q, D, dm; options=opt, nlind=nlind)
    rmprocs(workers())
    return f, g
end

### julia distributed setup ###
@batchdef function check_njulia(nsrc::Integer)
    if _nproc_loc == 1 || nsrc == 1
        @info "Only $(nsrc) source or $(_nproc_loc) workers, running serial julia"
        return
    end
    nw = nsrc >= _nproc_loc ? _nproc_loc : nsrc
    @info "Starting julia distributed with $(nw) workers for $(nsrc) sources"
    addprocs(nw)
    eval(macroexpand(Main, quote @everywhere using JUDI end))
end

