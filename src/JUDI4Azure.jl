module JUDI4Azure

using AzureClusterlessHPC, JUDI
import JUDI: judipmap

export Init_culster

_judi_defaults = Dict("_NODE_OS_OFFER"        => "UbuntuServer",
                    "_POOL_ID"                => "JudiPool",
                    "_POOL_VM_SIZE"           => "Standard_E8s_v3",
                    "_VERBOSE"                => "0",
                    "_NODE_OS_OFFER"          => "ubuntu-server-container",
                    "_NODE_OS_PUBLISHER"      => "microsoft-azure-batch",
                    "_JOB_ID"                 => "JudiAzHpc",
                    "_CONTAINER"              => "mloubout/judi-cpu:v1.0",
                    "_MPI_RUN"                => "0",
                    "_NUM_NODES_PER_TASK"     => "1",
                    "_OMP_NUM_THREADS"        => "8",
                    "_NUM_PROCS_PER_NODE"     => "1",
                    "_INTER_NODE_CONNECTION"  => "0",
                    "_NODE_COUNT_PER_POOL"    => "4",
                    "_NUM_RETRYS"             => "1",
                    "_POOL_COUNT"             => "1",
                    "_STANDARD_OUT_FILE_NAME" => "stdout.txt",
                    "_BLOB_CONTAINER"         => "juditmpblob",
                    "_PYTHONPATH"             => "/usr/local/lib/python3.8/dist-packages",
                    "_JULIA_DEPOT_PATH"       => "/root/.julia",
                    "_NODE_OS_SKU"            => "20-04-lts")


merge!(AzureClusterlessHPC.__params__, _judi_defaults)

function init_culster(nworkers=2, creds=nothing; vm_size="Standard_E8s_v3", verbose=0, kw...)
    if !isnothing(creds)
        isfile(creds) || throw(FileNotFoundError(creds))
        merge!(__AzureClusterlessHPC.__credentials__, JSON.parsefile(creds))
    end

    global AzureClusterlessHPC.__params__["_NODE_COUNT_PER_POOL"] = "$(nworkers)"
    global AzureClusterlessHPC.__params__["_POOL_VM_SIZE"] = "$(vm_size)"
    global AzureClusterlessHPC.__params__["_VERBOSE"] = "$(verbose)"
    create_pool()
end

function _cleanup_azure()
    delete_all_jobs()
    delete_container()
    delete_pool()
end

atexit(_cleanup_azure)

# Still basic.Need to overwrite each parallel function for efficiency (and bcast and such)
function JUDI.judipmap(func, iter::UnitRange; )
    println("Running on Azure")
    @batchdef az_func(i) = func(i)
    # This is very basic since it doesn't reduce. Need to do case by case reduction to be better.
    return @batchexec pmap(i -> az_func(name), iter)
end

sum(A::Array{BlobFuture}) = fetchreduce(A; op=+, remote=true, num_restart=0)
vcat(A::NTuple{N, BlobFuture}) = vcat(fetch(collect(A))...)
reduce(f, A::Array{BlobFuture}) = fetchreduce(A; op=+, remote=true, num_restart=0)

end # module
