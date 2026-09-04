module CfGRIBAxisArraysExt

using AxisArrays
using CfGRIB: CfGRIB, DataSet, AxisArrayWrapper

function Base.convert(::Type{AxisArrayWrapper}, dataset::DataSet)::AxisArrayWrapper
    multidimensional_idx = [length(size(v.data)) > 1 for v in values(dataset.variables)]
    multidimensional_keys = collect(keys(dataset.variables))[multidimensional_idx]

    shared_axis = [
        Axis{Symbol(k)}(dataset.variables[k].data) for k in keys(dataset.dimensions)
    ]

    datasets = NamedTuple{Tuple(Symbol.(multidimensional_keys))}((
        AxisArray(convert(Array, dataset.variables[k].data), shared_axis...) for
        k in multidimensional_keys
    ))

    return AxisArrayWrapper(
        dataset.dimensions, datasets, dataset.attributes, dataset.encoding
    )
end

Base.convert(::Type{AxisArray}, dataset::DataSet)::AxisArrayWrapper =
    convert(AxisArrayWrapper, dataset)

function __init__()
    CfGRIB.DEFAULT_BACKEND[] = AxisArrayWrapper
    return push!(CfGRIB.AVAILABLE_BACKENDS, :AxisArray)
end

end
