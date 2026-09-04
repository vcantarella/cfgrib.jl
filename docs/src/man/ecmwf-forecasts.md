# Downloading and Processing ECMWF Forecasts

ECMWF publishes its operational forecasts as
[open data](https://www.ecmwf.int/en/forecasts/datasets/open-data) under a
CC-BY-4.0 licence, no account needed. This page walks through fetching a small
slice of a forecast and reading it with CfGRIB.jl. Archived forecasts and
reanalyses (for example ERA5 from the
[Climate Data Store](https://cds.climate.copernicus.eu/)) arrive as GRIB files
too, so everything from [Opening the file](@ref) onwards applies to them as
well.

## Where the data lives

Every run is a directory of GRIB2 files, one per forecast step:

```
https://data.ecmwf.int/forecasts/{yyyymmdd}/{HH}z/ifs/0p25/oper/{yyyymmdd}{HH}0000-{step}h-oper-fc.grib2
```

- Runs start at `00`, `06`, `12` and `18` UTC. The `00` and `12` runs go out to
  240 h (every 3 h to 144 h, then every 6 h), the `06` and `18` runs to 90 h.
- Each step file holds every parameter on every level, well over 100 MB,
  and only the last few days stay online.
- Next to each `.grib2` sits a `.index` file with one JSON object per GRIB
  message: its `param`, `levtype`, `levelist`, `step`, and the message's
  `_offset` and `_length` in bytes.

The index is what makes the download cheap: pick the messages you want and
fetch only those byte ranges. This is the same trick ECMWF's own
`ecmwf-opendata` Python client uses.

## Downloading only what you need

`Dates` and `Downloads` are part of Julia. `JSON` is already a dependency of
CfGRIB.jl, add it to your own project with `Pkg.add("JSON")`. The snippet below
fetches 2 m temperature and 2 m dew point for the first 12 hours of yesterday's
`00` run, about 6 MiB instead of five full step files:

```julia
using Dates, Downloads, JSON
using CfGRIB

#  Yesterday's 00z run is guaranteed to be fully published
date = Dates.today() - Day(1)
yyyymmdd = Dates.format(date, "yyyymmdd")
base = "https://data.ecmwf.int/forecasts/$yyyymmdd/00z/ifs/0p25/oper"
prefix = "$(yyyymmdd)000000"

steps = 0:3:12
params = ("2t", "2d")
grib_path = "ecmwf-$prefix-2m.grib2"

open(grib_path, "w") do out
    for step in steps
        name = "$prefix-$(step)h-oper-fc"
        for line in eachline(Downloads.download("$base/$name.index"))
            msg = JSON.parse(line)
            (msg["levtype"] == "sfc" && msg["param"] in params) || continue
            first_byte = msg["_offset"]
            last_byte = first_byte + msg["_length"] - 1
            Downloads.download("$base/$name.grib2", out;
                headers = ["Range" => "bytes=$first_byte-$last_byte"])
        end
    end
end
```

GRIB messages are self-contained, so concatenating the ranges into one file
gives a valid GRIB file.

## Opening the file

```julia
ds = DataSet(grib_path)

keys(ds.variables)
#  "time", "step", "heightAboveGround", "latitude", "longitude", "valid_time", "t2m", "d2m"

ds.dimensions
#  OrderedDict("step" => 5, "longitude" => 1440, "latitude" => 721)
```

Variables are named by their CF name (`2t` becomes `t2m`). The data variables
are [`OnDiskArray`](@ref OnDiskArray)s that read from the GRIB file when
indexed, so opening a large file is cheap:

```julia
t2m = ds.variables["t2m"]
t2m.dimensions                   # ("step", "longitude", "latitude")
t2m.attributes["GRIB_units"]     # "K"
ds.variables["step"].data        # [0, 3, 6, 9, 12]
ds.variables["valid_time"].data  # seconds since 1970-01-01, one per step

field = t2m.data[3, :, :]        # the +6 h field, a 1440×721 Array{Float32}
```

Note the dimension order: Julia arrays are column-major, so longitude comes
before latitude, the reverse of xarray. Opening a file also writes a small
`.idx` cache next to it so the next `DataSet` skips scanning the GRIB.

## Selecting data with a backend

With [`DimensionalData`](https://github.com/rafaqz/DimensionalData.jl) loaded
the dataset converts to named arrays, and its selectors do the coordinate
lookups:

```julia
using DimensionalData

da = convert(CfGRIB.DimensionalArrayWrapper, ds)

#  Nearest grid point to Amsterdam at +6 h, in °C
da.t2m[step=At(6), latitude=Near(52.4), longitude=Near(4.9)] - 273.15

#  Time series over the 12 hours at the same point
da.t2m[latitude=Near(52.4), longitude=Near(4.9)] .- 273.15
```

`AxisArrays` works the same way through `CfGRIB.AxisArrayWrapper`, see
[Backends](@ref lib_backends).

## Pressure levels

Upper-air fields have `levtype == "pl"` and a `levelist` in the index. Filter
on both and the level turns into a dimension:

```julia
grib_path = "ecmwf-$prefix-t-pl.grib2"
open(grib_path, "w") do out
    for step in (0, 6)
        name = "$prefix-$(step)h-oper-fc"
        for line in eachline(Downloads.download("$base/$name.index"))
            msg = JSON.parse(line)
            (msg["levtype"] == "pl" && msg["param"] == "t" &&
             msg["levelist"] in ("500", "850")) || continue
            first_byte = msg["_offset"]
            last_byte = first_byte + msg["_length"] - 1
            Downloads.download("$base/$name.grib2", out;
                headers = ["Range" => "bytes=$first_byte-$last_byte"])
        end
    end
end

ds = DataSet(grib_path)
ds.variables["t"].dimensions          # ("step", "isobaricInhPa", "longitude", "latitude")
ds.variables["isobaricInhPa"].data    # [850, 500]

da = convert(CfGRIB.DimensionalArrayWrapper, ds)
da.t[step=At(6), isobaricInhPa=At(500), latitude=Near(52.4), longitude=Near(4.9)]
```

## One level type per file

Keep parameters that share a level type and level together, and put others in
their own file. CfGRIB.jl does not yet implement `filter_by_keys`, and it does
not detect conflicting scalar coordinates: combining `2t` (2 m) with `10u`
(10 m) in one file opens without error but labels both as
`heightAboveGround = 2`. Python cfgrib refuses such a file, CfGRIB.jl currently
does not.
