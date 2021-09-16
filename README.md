# JUDI4Cloud.jl

This package implements serverless parallelism on Azure (Azure batch) for [JUDI](https://github.com/slimgroup/JUDI.jl) using [AzureClusterlessHPC](https://github.com/microsoft/AzureClusterlessHPC.jl). 

Using this package overwrite the task parallelism in [JUDI](https://github.com/slimgroup/JUDI.jl) and will therefore throw the corresponding warnings. These warnings can be safely ignored, however, `JUDI` and `JUDI4Cloud` should not be used together. The current implementation doesn't allow to switch between Azure and conventional parallelism, it is left to the user to know which resources they will use.

## Installation

To install this package simply run the standard command

```julia
] add https://github.com/slimgroup/JUDI4Cloud.jl
```

***Note*** The default docker container used is based on `julia v1.6`. Since the communcation with Azure Blob is done through Serialization, it is highly recommended to use the same version of julia locally. If you use the default container, use `Julia v1.6`, and if you use you own container make sure to have compatible Julia versions.


## Usage

To use this package, simply replace `using JUDI` by `using JUDI4Cloud` at the top of your script. All JUDI functionnalities are reexported to make your script compatible.

Once `JUDI4Cloud` is imported, you can use its main functionnality to start an Azure batch pool to use as your serverless remote taks farm. To start a batch pool with `2` nodes and `4` threads per node run:

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

## Examples

A simple example is available at [examples/modeling_basic_2D.jl](https://github.gatech.edu/mlouboutin3/JUDI4Cloud.jl/blob/master/examples/modeling_basic_2D.jl). This example is a verbatim copy of the corresponding [JUDI](https://github.com/slimgroup/JUDI.jl) example, with the exception of the Azure setup at the top, and shows the seemless usability of this package.

## Future work

The following extensions are currently in developpement:

- GPU support. [JUDI](https://github.com/slimgroup/JUDI.jl) support's GPU offloading through [Devito](https://github.com/devitocodes/devito) and VM/Image/container support is beeing added
- More flexibility allowing to switch between conventional Julia parallelsim and Azure
- Some functionnalities are not supported yet (Extended source, TWRI), these will be added as well.


# Author

This software is develloped as Georgia Institute of Technology as part of the ML4Seismic consortium. For questions or issues, please open an issue on github or contact the author:

- Mathias Louboutin: mlouboutin3@gatech.edu
