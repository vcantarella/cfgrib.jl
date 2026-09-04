module CfGRIBDimensionalDataExt

using DimensionalData
using CfGRIB: CfGRIB, DataSet, DimensionalArrayWrapper

function Base.convert(::Type{DimensionalArrayWrapper}, dataset::DataSet)::DimensionalArrayWrapper
    multidimensional_idx = (
        [size(v.data) for v in values(dataset.variables)]
        .|> length
        .|> x -> x > 1)
    multidimensional_keys = collect(keys(dataset.variables))[multidimensional_idx]

    shared_axis = [Dim{Symbol(k)}(dataset.variables[k].data) for k in keys(dataset.dimensions)]

    datasets = NamedTuple{Tuple(Symbol.(multidimensional_keys))}((
        DimArray(convert(Array, dataset.variables[k].data), Tuple(shared_axis))
        for k in multidimensional_keys
    ))

    return DimensionalArrayWrapper(dataset.dimensions, datasets, dataset.attributes, dataset.encoding)
end

Base.convert(::Type{DimArray}, dataset::DataSet)::DimensionalArrayWrapper = convert(DimensionalArrayWrapper, dataset)

function __init__()
    CfGRIB.DEFAULT_BACKEND[] = DimensionalArrayWrapper
    push!(CfGRIB.AVAILABLE_BACKENDS, :DimensionalArray)
end

end
