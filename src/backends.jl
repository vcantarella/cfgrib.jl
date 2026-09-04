using FileIO


const BACKEND_PROVIDERS = [:AxisArrays, :DimensionalData]
#  Filled in by the package extensions in `ext/` when one of the
#  `BACKEND_PROVIDERS` packages is loaded alongside CfGRIB. Last loaded wins.
const AVAILABLE_BACKENDS = Symbol[]
const DEFAULT_BACKEND = Ref{Any}(DataSet)

"""
Backends are wrappers around named array data types, contain information on the
dimensions, attributes, and encoding of the data, as well as the datasets
themselves.

# See also

[`AxisArrayWrapper`](@ref AxisArrayWrapper),
[`DimensionalArrayWrapper`](@ref DimensionalArrayWrapper)
"""
abstract type Backend end

"""
Abstract type for backends which also wrap data types provided by external
packages, instead of just providing a 'vanilla' implementation of the data type.

Python's `xarray` has two fundamental data structures, a `DataArray` which holds
the data for a **single** multi-dimensional variable and its coordinates, as
well as a `Dataset` which holds **multiple DataArrays** that (typically) share
the same coordinates.

# See also

[`AxisArrayWrapper`](@ref AxisArrayWrapper),
[`DimensionalArrayWrapper`](@ref DimensionalArrayWrapper)
"""
abstract type ArrayWrapper <: Backend end

include("./backends/dimensionaldata.jl")
include("./backends/axisarrays.jl")

#  Fallback hit when the backend package has not been loaded, so the extension
#  providing the real `convert` method is not active
Base.convert(::Type{T}, ::DataSet) where {T<:ArrayWrapper} = error(
    "$T is not available, `using` one of $BACKEND_PROVIDERS activates it"
)


function fileio_load(f::File{format"GRIB"}; backend=DEFAULT_BACKEND[], kwargs...)
    """ Load command for FileIO integration. Following line must be in the
    FileIO Registry for this to function properly:

        add_format(format"GRIB", UInt8[0x47, 0x52, 0x49, 0x42], ".grib", [:CfGRIB])
    """
    ds = DataSet(f.filename, kwargs...)
    return convert(backend, ds)
end
