## jupyter as slideshow
https://rise.readthedocs.io/en/stable/installation.html

```julia
using Pkg
Pkg.add("Conda")
using Conda
Conda.add_channel("conda-forge")
Conda.add("rise")
```

## activate conda environment
To activate that conda environment, take a look at `Conda.ROOTENV`, which is e.g. `~/.julia/conda/3`

and do

`source ~/.julia/conda/3/bin/activate`.

## install `nbstripout`
https://github.com/kynan/nbstripout

In the conda environment, do
`conda install -c conda-forge nbstripout`
