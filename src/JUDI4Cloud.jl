module JUDI4Cloud

import Base.+

using AzureClusterlessHPC, Reexport
@reexport using JUDI
import JUDI: run_and_reduce

export init_culsterless, azurepool

_njpi = 1
_default_container = "mloubout/judi4cloud:latest"

_judi_defaults = Dict("_POOL_ID"                => "JudiPool",
                    "_POOL_VM_SIZE"           => "Standard_E8s_v3",
                    "_VERBOSE"                => "0",
                    "_NODE_OS_OFFER"          => "ubuntu-server-container",
                    "_NODE_OS_PUBLISHER"      => "microsoft-azure-batch",
                    "_CONTAINER"              => _default_container,
                    "_NODE_COUNT_PER_POOL"    => "4",
                    "_NUM_RETRYS"             => "1",
                    "_POOL_COUNT"             => "1",
                    "_PYTHONPATH"             => "/usr/local/lib/python3.8/dist-packages",
                    "_JULIA_DEPOT_PATH"       => "/root/.julia",
                    "_OMP_NUM_THREADS"        => "4",
                    "_NODE_OS_SKU"            => "20-04-lts")



################################################################################
#########################  JUDI extension  #####################################

struct AzurePool
    name::String
end

azurepool() = AzurePool("Batch Pool $(AzureClusterlessHPC.__params__["_POOL_ID"])")

function set_env_vars(gpu::Bool)
    if gpu
        ENV["DRVITO_ARCH"] = "nvc"
        ENV["DRVITO_PLATFORM"] = "nvidiaX"
        ENV["DRVITO_LANGUAGE"] = "openacc"
    end
end

judi_reduction_code = quote
    @batchdef function remote_reduction(_x, _y; op=+)
        x = fetch(_x)
        y = fetch(_y)
        JUDI.single_reduce!(x, y)
        return x
    end
end

remote_func_code(gpu::Bool) = quote
  @batchdef function judifunc(func::Function, args)
      set_env_vars($(gpu))
      argout = func(args...)
      return argout
  end
end

"""
    run_and_reduce(func, pool, nsrc, arg_func)

Runs the function `func` for indices `1:nsrc` within arguments `func(arg_func(i))`. If the 
the pool is empty, a standard loop and accumulation is ran. If the pool is a julia WorkerPool or
any custom Distributed pool, the loop is distributed via `remotecall` followed by are binary tree remote reduction.
"""
function run_and_reduce(func, ::AzurePool, nsrc, arg_func::Function)
    # Make args indexable so that Redwood doesn't copy everything on every worker
    args_indexable = [arg_func(i) for i=1:nsrc]
    res = eval(:(@batchexec pmap(i -> judifunc($(func), $(args_indexable)[i]), 1:$(nsrc))))
    res = fetchreduce(res; remote=true, reduction_code=judi_reduction_code)
    return res
end

"""
    init_culsterless(nworkers; kw...)

Initialze the serverless Azure Batch pool with `nworkers` instances/nodes

Parameters
* `nworkers`: Number of instances ine the Azure batch pool.
* `credentials`: Path to credentials file. See AzureClusterlessHPC for more details.

* `pool_name`: Name of the pool
* `vm_size`: Type of virtual machine (vm) to use for the pool. You can provide a list of vm sizes in which case it will creeate one pool per type of vm.
Check your azure batch quotas to make sure this is available for you.
* `verbose`: whether to turn on (1) or of (0) AzureClusterlessHPC verbosity.
* `nthreads`: Sets `OMP_NUM_THREADS=nthreads` on each node.
* `auto_scale`: Whether to enable autoscale. If enabled, the pool will start with no node and automatically scale based on the number of tasks.
* `n_julia_per_instance`: Number of julia worker per node (Default 1). If >1, julia will start a mini distributed setup on each node based on the number of source.
"""
function init_culsterless(nworkers=2; credentials=nothing, vm_size="Standard_E8s_v3",
                          pool_name="JudiPool", verbose=0, nthreads=4, gpu=false,
                          auto_scale=false, n_julia_per_instance=1,
                          container=_default_container, kw...)
    isnothing(credentials) && throw(InputError("`credentials` must be a valid path to Azure json Credentials"))
    # Check VM type
    if gpu && !any(startswith.(split(_POOL_VM_SIZE, "_")[2], ["NV", "ND", "NC"]))
        @warn "GPU propagation requested on a CPU instance,m disabling gpu. Chose one of NV/NC/ND instance for GPU acceleration"
        gpu = false
    end
    # Check input
    blob_name = lowercase("$(pool_name)tmp")
    # Update verbosity and parameters
    @eval(AzureClusterlessHPC, global __verbose__ =  Bool($verbose))
    global AzureClusterlessHPC.__params__["_NODE_COUNT_PER_POOL"] = "$(nworkers)"
    global AzureClusterlessHPC.__params__["_POOL_ID"] = "$(pool_name)"
    global AzureClusterlessHPC.__params__["_POOL_COUNT"] = "1"
    global AzureClusterlessHPC.__params__["_POOL_VM_SIZE"] = vm_size
    global AzureClusterlessHPC.__params__["_OMP_NUM_THREADS"] = "$(nthreads)"
    global AzureClusterlessHPC.__params__["_VERBOSE"] = "$(verbose)"
    global AzureClusterlessHPC.__params__["_BLOB_CONTAINER"] = blob_name
    global AzureClusterlessHPC.__params__["_CONTAINER"] = container
    # reinit everything
    isfile(credentials) || throw(FileNotFoundError(credentials))
    creds = AzureClusterlessHPC.JSON.parsefile(credentials)
    @eval(AzureClusterlessHPC, global __container__ = $blob_name)
    @eval(AzureClusterlessHPC, global __credentials__ = [$creds])
    @eval(AzureClusterlessHPC, global __resources__ = [[] for i=1:length(__credentials__)])
    @eval(AzureClusterlessHPC, global __clients__ = create_clients(__credentials__, batch=true, blob=true))

    # Create pool with idle autoscale. This will be much more efficient with a defined image rather than docker.
    create_pool()

    # Export JUDI on azure
    eval(macroexpand(JUDI4Cloud, quote @batchdef using Distributed, JUDI end))
    global _njpi = isnothing(n_julia_per_instance) ? 1 : n_julia_per_instance
    # Define number of local julia worker on each node in batch
    eval(macroexpand(JUDI4Cloud, quote @batchdef _nproc_loc = $_njpi end))
    eval(macroexpand(JUDI4Cloud, remote_func_code($gpu)))
    
    @eval(JUDI, _worker_pool() = $(azurepool)())
end

"""
    finalize_culsterless()

Finalize the clusterless job and deletes all resources (pool, tmp container, jobs)
"""
function finalize_culsterless()
    delete_all_jobs()
    delete_container()
    try delete_pool() catch; nothing end
end


function __init__()
    # Runtime (on node) doesn't need AzHPC
    if !haskey(ENV, "AZ_BATCH_TASK_WORKING_DIR")
        merge!(AzureClusterlessHPC.__params__, _judi_defaults)
        atexit(finalize_culsterless)
    end
end

end # module
