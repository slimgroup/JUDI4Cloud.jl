# JUDI4Azure.jl

This packages implements serverless parallelism on Azure (Azure batch) for JUDI using [AzureClusterlessHPC](https://github.com/microsoft/AzureClusterlessHPC.jl). 

Using this package overwrite the task parallelism in [JUDI](https://github.com/slimgroup/JUDI.jl) and will therefore throw the corresponding warnings. These warnings can be safely ignored, however, `JUDI` and `JUDI4Azure` should not be used together. The current implementation doesn't allow to switch between azure and conventional parallelism, it is left to the user to know which resources they will use.

## Usage

To use this package, simply replace `using JUDI` by `using JUDI4Azure` at the top of your script. All JUDI functionnalities are reexported to make your script compatible.

Once `JUDI4Azure` imported, you can use its main functionnality to start an Azure batch pool to use as your serverless remote taks farm. To start a batch pool with `2` nodes and `4` threads per node run:

```julia
nworkers = 2
init_culsterless(nworkers; credentials=creds, vm_size="Standard_E2s_v3", pool_name="PoolTest", verbose=1, nthreads=4)
```

where:
- `creds` is the path to your credentials JSON file (see [credentials](https://microsoft.github.io/AzureClusterlessHPC.jl/credentials/) for informations)
- `vm_size` is the Azure VM you want to use. This VM need to be available in your bqatch account
- `pool_name`  is the of the batch pool of nodes
- `verbose` controls [AzureClusterlessHPC](https://github.com/microsoft/AzureClusterlessHPC.jl)'s verbosity
- `nthreads` defines the number of OpenMP threads to use on each node

## Examples

A simple example is available at [examples/modeling_basic_2D.jl](https://github.gatech.edu/mlouboutin3/JUDI4Azure.jl/blob/master/examples/modeling_basic_2D.jl). This example si the verbatim copy of the corresponding JUDI example, with the exception of the Azure setup at the top, and shows the seemless usxability of this package.

## Future work

The following extensions are currently in developpement:

- GPU support. [JUDI](https://github.com/slimgroup/JUDI.jl) support's GPU offloading through [Devito](https://github.com/devitocodes/devito) and VM/Image/container support is beeing added
- More flexibility allowing to switch between conventional julia parallelsim and Azure
- Some functionnalities are currently not supported yet (Extended source, TWRI), these will be added as well


# Author

This software is develloped as Georgia Institute of Technology as part of the ML4Seismic consortium. For questions or issues, please open an issue on github or contact the author:

- Mathias Louboutin: mlouboutin3@gatech.edu