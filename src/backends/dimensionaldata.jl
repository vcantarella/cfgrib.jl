using DataStructures

import Base: getindex, keys, haskey, convert, show, IO, MIME


"""
DimensionalData provides the equivalent of an xarray `DataArray`, this wrapper
adds the functionality of an xarray `DataSet` by containing multiple
`DimensionalArray`s.

Object should be created by calling the relevant
`convert($(FUNCTIONNAME), dataset::DataSet)` method on a [`DataSet`](@ref DataSet).

# See also

[`Backend`](@ref Backend), [`ArrayWrapper`](@ref ArrayWrapper)
"""
struct DimensionalArrayWrapper <: ArrayWrapper
    "Dictionary of `DimensionName::String => DimensionLength::Int`"
    dimensions::OrderedDict
    "Named tuple of `DatasetName::Symbol => Dataset::DimensionalArray`"
    datasets::T where T <: NamedTuple
    "Dictionary of `AttributeName::String => AttributeValue::Any`"
    attributes::OrderedDict
    "Dictionary containing encoding information (usually `source`, `filter_by_keys`, and `ecode_cf`)"
    encoding::Dict

    #  Manually define inner constructor here so that it does not appear twice
    #  in the docs
    DimensionalArrayWrapper(dimensions, datasets, attributes, encoding) = new(dimensions, datasets, attributes, encoding)
end

getindex(obj::DimensionalArrayWrapper, key) = getfield(obj, :datasets)[key]
keys(obj::DimensionalArrayWrapper) = keys(getfield(obj, :datasets))
haskey(obj::DimensionalArrayWrapper, key) = key in keys(obj)

function Base.getproperty(obj::DimensionalArrayWrapper, key::Symbol)
    if key in keys(obj)
        return getindex(obj, key)
    else
        return getfield(obj, key)
    end
end

#  `convert(DimensionalArrayWrapper, ::DataSet)` lives in ext/CfGRIBDimensionalDataExt.jl
