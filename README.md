# CfGRIB.jl

[![lifecycle](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![Apache 2 license](https://img.shields.io/github/license/vcantarella/cfgrib.jl)](https://github.com/vcantarella/cfgrib.jl/blob/dev/LICENSE)
[![Tests](https://github.com/vcantarella/cfgrib.jl/actions/workflows/Tests.yml/badge.svg)](https://github.com/vcantarella/cfgrib.jl/actions/workflows/Tests.yml)
[![Documentation](https://github.com/vcantarella/cfgrib.jl/actions/workflows/Docs.yml/badge.svg)](https://github.com/vcantarella/cfgrib.jl/actions/workflows/Docs.yml)
[![Codecov](https://codecov.io/gh/vcantarella/cfgrib.jl/branch/dev/graph/badge.svg)](https://codecov.io/gh/vcantarella/cfgrib.jl)
[![docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://vcantarella.github.io/cfgrib.jl/dev/)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/JuliaDiff/BlueStyle)

## Description
CfGRIB.jl is a julia interface to map GRIB files to the [Unidata's Common Data
Model v4](https://www.unidata.ucar.edu/software/thredds/current/netcdf-java/CDM/)
following the [CF Conventions](http://cfconventions.org).

This package is based on the python implementation in
[cfgrib.py](https://github.com/ecmwf/cfgrib) and closely follows the approaches
of that package, but in Julia instead. Parity tests are automatically performed
between the two to ensure that the data returned by the Julia version is
equivalent to that from Python.

In Python [xarray](http://xarray.pydata.org) has come out to be a standard
way to implement named arrays, however as Julia is a much younger language no
stable array interface has been adopted by the community yet, so the approach
here is more flexible and allows for multiple array backends to be used.

Currently two array backends are supported:
- [`AxisArrays`](https://github.com/JuliaArrays/AxisArrays.jl)
- [`DimensionalData`](https://github.com/rafaqz/DimensionalData.jl)

Load either package alongside CfGRIB.jl and the matching backend switches on
(they are package extensions), otherwise only the built-in bare data types are
returned.

Low level access and decoding is performed by calling
[GRIB.jl](https://github.com/weech/GRIB.jl) which itself calls the
[ECMWF ecCodes library](https://software.ecmwf.int/wiki/display/ECC/).

CfGRIB.jl started at ECMWF as [ecmwf/cfgrib.jl](https://github.com/ecmwf/cfgrib.jl),
written by Robert Rosca. This repository continues that work.

## Installation
The package is not on the Julia registry yet, so install it straight from
GitHub. GRIB.jl and the ecCodes library come along automatically:

```julia
] add https://github.com/vcantarella/cfgrib.jl
```

For a named-array backend add one of the supported packages as well:

```julia
] add DimensionalData   # or AxisArrays
```

Then:

```julia
using CfGRIB, DimensionalData

ds = DataSet("forecast.grib")
da = convert(CfGRIB.DimensionalArrayWrapper, ds)
```

The [documentation](https://vcantarella.github.io/cfgrib.jl/dev/) has an
in-depth guide to the package and a worked example of downloading and
processing ECMWF open-data forecasts.

## Development and Contribution
Clone the repository and run the tests from its project:

```shell
git clone https://github.com/vcantarella/cfgrib.jl
cd cfgrib.jl
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

The parity tests compare against Python's cfgrib, which the test suite installs
into a Conda environment on first run.

Code follows the [Blue style](https://github.com/JuliaDiff/BlueStyle) and CI
checks it with [JuliaFormatter](https://github.com/domluna/JuliaFormatter.jl).
Format before committing with:

```shell
julia -e 'using JuliaFormatter; format(".")'
```
