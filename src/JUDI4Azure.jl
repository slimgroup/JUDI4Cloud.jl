module JUDI4Azure

using AzureClusterlessHPC, Reexport

@reexport using JUDI
import JUDI: judipmap

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
                    "_STANDARD_OUT_FILE_NAME" => "stdout.txt",
                    "_BLOB_CONTAINER"         => "juditmpblob",
                    "_PYTHONPATH"             => "/usr/local/lib/python3.8/dist-packages",
                    "_JULIA_DEPOT_PATH"       => "/root/.julia",
                    "_NODE_OS_SKU"            => "20-04-lts")


function init_culsterless(nworkers=2; credentials=nothing, vm_size="Standard_E8s_v3", verbose=0, kw...)
    if !isnothing(credentials)
        # reinit everything
        isfile(credentials) || throw(FileNotFoundError(credentials))
        creds = AzureClusterlessHPC.JSON.parsefile(credentials)
        @eval(AzureClusterlessHPC, global __credentials__ = [$creds])
        @eval(AzureClusterlessHPC, global __resources__ = [[] for i=1:length(__credentials__)])
        @eval(AzureClusterlessHPC, global __clients__ = create_clients(__credentials__, batch=true, blob=true))
    end

    @eval(AzureClusterlessHPC, global __verbose__ = $verbose)
    global AzureClusterlessHPC.__params__["_NODE_COUNT_PER_POOL"] = "$(nworkers)"
    global AzureClusterlessHPC.__params__["_POOL_VM_SIZE"] = "$(vm_size)"
    global AzureClusterlessHPC.__params__["_VERBOSE"] = "$(verbose)"
    create_pool()
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

# Still basic.Need to overwrite each parallel function for efficiency (and bcast and such)
function JUDI.judipmap(func, iter::UnitRange; )
    println("Running on Azure")
    @batchdef az_func(i) = func(i)
    # This is very basic since it doesn't reduce. Need to do case by case reduction to be better.
    return @batchexec pmap(i -> az_func(name), iter)
end

sum(A::Array{BlobFuture}) = fetchreduce(A; op=+, remote=true, num_restart=0)
vcat(A::NTuple{N, BlobFuture}) where N = vcat(fetch(collect(A))...)
reduce(f, A::Array{BlobFuture}) = fetchreduce(A; op=+, remote=true, num_restart=0)

end # module
