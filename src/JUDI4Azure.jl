module JUDI4Azure

using AzureClusterlessHPC, Reexport

@reexport using JUDI

export init_culsterless

_judi_defaults = Dict("_POOL_ID"                => "JudiPool",
                    "_POOL_VM_SIZE"           => "Standard_E8s_v3",
                    "_VERBOSE"                => "0",
                    "_NODE_OS_OFFER"          => "ubuntu-server-container",
                    "_NODE_OS_PUBLISHER"      => "microsoft-azure-batch",
                    "_JOB_ID"                 => "JudiAzHpc",
                    "_CONTAINER"              => "mloubout/judi-cpu:1.0",
                    "_NODE_COUNT_PER_POOL"    => "4",
                    "_NUM_RETRYS"             => "1",
                    "_POOL_COUNT"             => "1",
                    "_PYTHONPATH"             => "/usr/local/lib/python3.8/dist-packages",
                    "_JULIA_DEPOT_PATH"       => "/root/.julia",
                    "_NODE_OS_SKU"            => "20-04-lts")


function init_culsterless(nworkers=2; credentials=nothing, vm_size="Standard_E8s_v3", pool_name="JudiPool", verbose=0, kw...)
    if !isnothing(credentials)
        # reinit everything
        isfile(credentials) || throw(FileNotFoundError(credentials))
        creds = AzureClusterlessHPC.JSON.parsefile(credentials)
        @eval(AzureClusterlessHPC, global __credentials__ = [$creds])
        @eval(AzureClusterlessHPC, global __resources__ = [[] for i=1:length(__credentials__)])
        @eval(AzureClusterlessHPC, global __clients__ = create_clients(__credentials__, batch=true, blob=true))
    end

    @eval(AzureClusterlessHPC, global __verbose__ =  Bool($verbose))
    global AzureClusterlessHPC.__params__["_NODE_COUNT_PER_POOL"] = "$(nworkers)"
    global AzureClusterlessHPC.__params__["_POOL_VM_SIZE"] = "$(vm_size)"
    global AzureClusterlessHPC.__params__["_VERBOSE"] = "$(verbose)"
    create_pool()
    # Export JUDI on azure
    eval(macroexpand(JUDI4Azure, quote @batchdef using JUDI end))
end

"""
    finalize_culsterless()

Finalize the clusterless job and deletes all resources (pool, tmp container, jobs)
"""
function finalize_culsterless()
    delete_all_jobs()
    delete_container()
    delete_pool()
end


function __init__()
    merge!(AzureClusterlessHPC.__params__, _judi_defaults)
    atexit(finalize_culsterless)
end

# Modeling functions
include("modeling.jl")

end # module
