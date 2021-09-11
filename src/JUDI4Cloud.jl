module JUDI4Cloud

import Base.+

using AzureClusterlessHPC, Reexport, Dates
@reexport using JUDI

export init_culsterless

_njpi = 1
_default_container = "mloubout/judi-cpu:1.4.3"

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

"""
Define auto scale formula to avoid idle pools
"""
auto_scale_formula(x) = """
\$TargetDedicatedNodes = $x
// Get pending tasks for the past 15 minutes.
\$samples = \$ActiveTasks.GetSamplePercent(TimeInterval_Minute * 15);
// If we have fewer than 70 percent data points, we use the last sample point, otherwise we use the maximum of last sample point and the history average.
\$tasks = \$samples < 70 ? max(0, \$ActiveTasks.GetSample(1)) : 
max( \$ActiveTasks.GetSample(1), avg(\$ActiveTasks.GetSample(TimeInterval_Minute * 15)));
// If number of pending tasks is not 0, set targetVM to pending tasks, otherwise 25% of current dedicated.
\$targetVMs = \$tasks > 0 ? \$tasks : max(0, \$TargetDedicatedNodes / 4);
// The pool size is capped at NWORKERS, if target VM value is more than that, set it to NWORKERS.
cappedPoolSize = $x;
// Always start the pool at full size and keep it there for 10 minutes
\$TargetDedicatedNodes = max(0, min(\$targetVMs, cappedPoolSize));"""


len_vm(s::String) = 1
len_vm(s::Array{String, 1}) = len(s)
len_vm(s) = throw(ArgumentError("`vm_size` must be a String Array{String, 1}"))


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
                          pool_name="JudiPool", verbose=0, nthreads=4,
                          auto_scale=true, n_julia_per_instance=1,
                          container=_default_container, kw...)
    isnothing(credentials) && throw(InputError("`credentials` must be a valid path to Azure json Credentials"))
    # Check input
    npool = len_vm(vm_size)
    blob_name = lowercase("$(pool_name)tmp")
    # Update verbosity and parameters
    @eval(AzureClusterlessHPC, global __verbose__ =  Bool($verbose))
    global AzureClusterlessHPC.__params__["_NODE_COUNT_PER_POOL"] = "$(nworkers)"
    global AzureClusterlessHPC.__params__["_POOL_ID"] = "$(pool_name)"
    global AzureClusterlessHPC.__params__["_POOL_COUNT"] = "$(npool)"
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
    if auto_scale
        create_pool(;enable_auto_scale=auto_scale,
                    auto_scale_formula=auto_scale_formula(nworkers), 
                    auto_scale_evaluation_interval_minutes=5)
    else
        create_pool()
    end

    # Export JUDI on azure
    eval(macroexpand(JUDI4Cloud, quote @batchdef using Distributed, JUDI end))
    global _njpi = isnothing(n_julia_per_instance) ? 1 : n_julia_per_instance
    # Define number of local julia worker on each node in batch
    eval(macroexpand(JUDI4Cloud, quote @batchdef _nproc_loc = $_njpi end))
    include(joinpath(@__DIR__, "batch_defs.jl"))
    include(joinpath(@__DIR__, "modeling.jl"))
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
    merge!(AzureClusterlessHPC.__params__, _judi_defaults)
    atexit(finalize_culsterless)
end

end # module
