using JUDI4Cloud

import JUDI4Cloud.AzureClusterlessHPC: @batchexec, @bcast, @batchdef, linefilter!
using JUDI4Cloud.AzureClusterlessHPC

creds = "/home/mloubout/research/azure/clusterless_creds.json"
# creds = "/Users/mathiaslouboutin/research/AzureSlim/custerless/credentials.json"
init_culsterless(2; credentials=creds, vm_size="Standard_E2s_v3", auto_scale=false,
                 pool_name="BatchBatch2", n_julia_per_instance=2, verbose=1)

@batchdef function makevec(i)
    pm = randn(100)
    return pm
end

result = @batchexec pmap(i->makevec(i), 1:2)
fetched = fetchreduce(result; op=+, remote=true)