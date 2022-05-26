# JUDI4Cloud.jl

This package implements serverless parallelism on Azure (Azure batch) for [JUDI] using [AzureClusterlessHPC]. 

## Installation

To install this package simply run the standard command

```julia
] add https://github.com/slimgroup/JUDI4Cloud.jl
```

***Note*** The default docker container used is based on `julia v1.7`. Since the communication with Azure Blob is done through Serialization, it is **mandatory** to use the same version of Julia locally. If you use the default container, use `Julia v1.7`, and if you use your own container make sure to have compatible Julia versions.

## Remote container

Following [AzureClusterlessHPC] convention, we rely on a remote runtime docker container with all the necessary packages installed and the runtime version of [AzureClusterlessHPC] installed. For convenience, we provide a docker container with the latest version of [AzureClusterlessHPC], [JUDI4Cloud] and [JUDI] installed for Julia `1.6` or `1.7`. These images are named `mloubout/judi4cloud:1.6` and `mloubout/judi4cloud:1.7`. This image contains additional SLIM packages as well such as `SegyIO` if the user were to need it.

Additionally, these two premade images provide the Nvidia HPC SDK to enable GPU accceleration of the propagators. You can therefore use GPU instances as well. Enabling GPU can be done by specifying `gpu=true` when initializing the batch pool.


## Usage

To use this package, simply replace `using JUDI` by `using JUDI4Cloud` at the top of your script. All JUDI functionalities are reexported to make your script compatible.

Once `JUDI4Cloud` is imported, you can use its main functionality to start an Azure batch pool to use as your serverless remote task farm. To start a batch pool with `2` nodes and `4` threads per node run:

```julia
nworkers = 2
init_culsterless(nworkers; credentials=creds, vm_size="Standard_E2s_v3", pool_name="PoolTest", verbose=1, nthreads=4)
```

where:
- `creds` is the path to your credentials JSON file (see [credentials](https://microsoft.github.io/AzureClusterlessHPC.jl/credentials/) for information)
- `vm_size` is the Azure VM you want to use. This VM needs to be available in your batch account
- `pool_name`  is the of the batch pool of nodes
- `verbose` controls [AzureClusterlessHPC](https://github.com/microsoft/AzureClusterlessHPC.jl)'s verbosity
- `nthreads` defines the number of OpenMP threads to use on each node
- `gpu` whether to use (Nvidia) gpu for the propagators via openacc. You will need to specify a GPU VM.

## Examples

A simple example is available at [examples/modeling_basic_2D.jl](https://github.com/slimgroup/JUDI4Cloud.jl/blob/master/examples/modeling_basic_2D.jl). This example is a verbatim copy of the corresponding [JUDI](https://github.com/slimgroup/JUDI.jl) example, with the exception of the Azure setup at the top, and shows the seamless usability of this package.

## Future work

The following extensions are currently in development:

- Parallel Julia on each node.
- More flexibility to switch between conventional Julia parallelism and Azure
- Out of core judiVector with Blob storage

# Author

This software is developed at Georgia Institute of Technology as part of the ML4Seismic consortium. For questions or issues, please open an issue on GitHub or contact the author:

- Mathias Louboutin: mlouboutin3@gatech.edu


[AzureClusterlessHPC]:https://github.com/microsoft/AzureClusterlessHPC.jl
[JUDI]:https://github.com/slimgroup/JUDI.jl