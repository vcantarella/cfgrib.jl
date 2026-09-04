using DataStructures
using GRIB
using Serialization


export FileIndex


"""
A mutable store for indices of a GRIB file

TODO: Should probably change this to a immutable struct
"""
mutable struct FileIndex
    "Version number used when saving/hashing index files, should change if the indexing structure changes breaking backwards-compatibility"
    allowed_protocol_version::VersionNumber

    "Path to the file the index belongs to"
    grib_path::String
    "Path to the index cache file"
    index_path::String

    "Array containing all of the index keys"
    index_keys::Array{String,1}
    "Array containing pairs of `offsets[HeaderTuple(header_values)] => offset_field`"
    offsets::Array{Pair{T where T <: NamedTuple,Int},1}
    "Array containing the length of each message in the GRIB file"
    message_lengths::Array{Int,1}
    "Dictionary of all of the loaded header values in the GRIB file"
    header_values::OrderedDict{String,Array}

    "Filters used when creating the file index"
    filter_by_keys::Dict

    FileIndex() = new(v"0.0.0")
end

function FileIndex(
    grib_path::String,
    index_keys::Array{String,1};
    filter_by_keys::Dict=Dict(),
)::FileIndex
    fileindex = FileIndex()
    fileindex.grib_path = grib_path
    fileindex.index_keys = index_keys

    if !from_indexfile!(fileindex)
        from_gribfile!(fileindex)
        save_indexfile(fileindex)
    end
    get_header_values!(fileindex)

    if length(filter_by_keys) > 0
        fileindex = filter(fileindex, filter_by_keys...)
    end

    return fileindex
end

Base.getindex(obj::FileIndex, key) = obj.header_values[key]


function index_path(index::FileIndex)
    index_keys_hash = hash(
        join([index.index_keys..., index.allowed_protocol_version])
    )
    index_keys_hash = string(index_keys_hash, base=16)

    return "$(index.grib_path).$index_keys_hash.idx"
end

index_path!(index::FileIndex) = setfield!(index, :index_path, index_path(index))


#  Stored in the index file so a cache left behind by an older copy of the GRIB
#  is detected, mirrors upstream cfgrib's filestamp check
grib_filestamp(path) = (mtime(path), filesize(path))

"""
Serialise the offsets and message lengths of `index` to `index.index_path` so
the next `FileIndex` for the same file and keys skips scanning the GRIB.
Failing to write is not fatal, the index just is not cached.
"""
function save_indexfile(index::FileIndex)
    index_path!(index)
    try
        serialize(index.index_path, (
            index.allowed_protocol_version,
            index.index_keys,
            grib_filestamp(index.grib_path),
            index.offsets,
            index.message_lengths,
        ))
    catch e
        @warn "Could not write index file $(index.index_path)" exception = e
    end
end

"""
Load `offsets` and `message_lengths` from `index.index_path`. Returns `false`
and leaves `index` untouched when there is no index file, or it is unreadable,
written with another protocol version or key set, or older than the GRIB file.
"""
function from_indexfile!(index::FileIndex)::Bool
    index_path!(index)
    isfile(index.index_path) || return false

    try
        version, index_keys, filestamp, offsets, message_lengths = deserialize(index.index_path)
        if version != index.allowed_protocol_version ||
           index_keys != index.index_keys ||
           filestamp != grib_filestamp(index.grib_path)
            @debug "Ignoring index file $(index.index_path) incompatible with GRIB file"
            return false
        end
        index.offsets = offsets
        index.message_lengths = message_lengths
    catch e
        @debug "Ignoring unreadable index file $(index.index_path)" exception = e
        return false
    end

    return true
end


function from_gribfile!(index::FileIndex)
    offsets = OrderedDict{T where T <: NamedTuple,Int}()
    count_offsets = Dict{Int,Int}()

    index_keys = index.index_keys
    index_key_count = length(index_keys)
    index_key_symbols = Tuple(Symbol.(index_keys))
    HeaderTuple = NamedTuple{index_key_symbols}

    GribFile(index.grib_path) do f
        message_lengths = Int[]
        for message in f
            header_values = Array{Any}(undef, index_key_count)
            for (i, key) in enumerate(index_keys)
                value = read_message(message, key)

                # #  Useful for debugging
                # value_naive = haskey(message, key) ? message[key] : missing
                # value_naive = value_naive isa Array ? Tuple(value_naive) : value_naive
                # value_naive = key == "time" ? from_grib_date_time(message) : value_naive
                # if any(ismissing.([value_naive, value]))
                #     if !all(ismissing.([value_naive, value]))
                #         println("$key: $value vs $value_naive")
                #     end
                # elseif value_naive != value
                #     println("$key: $value vs $value_naive")
                # end

                header_values[i] = value
            end

            offset = Int(message["offset"])
            if offset in keys(count_offsets)
                count_offsets[offset] += 1
                offset_field = (offset, count_offsets[offset])
            else
                count_offsets[offset] = 0
                offset_field = offset
            end

            push!(message_lengths, Int(message["totalLength"]))
            offsets[HeaderTuple(header_values)] = offset_field
        end
        index.message_lengths = message_lengths
    end

    index.offsets = collect(pairs(offsets))
end


function get_header_values!(index::FileIndex)
    header_values = OrderedDict{String,Array}()
    for key in index.index_keys
        header_values[key] = unique([
            offset[1][Symbol(key)]
            for offset
            in index.offsets
        ])
    end

    index.header_values = header_values
end


function getone(index::FileIndex, item)
    values = index[item]

    if length(values) != 1
        throw("Expected 1 value for $(item), found $(length(values)) instead")
    end

    return values[1]
end


function first(index::FileIndex)
    GribFile(index.grib_path) do file
        first_offset = index.offsets[1][2][1]
        #  There is a discrepancy between how offsets are defined and used
        #  in cfgrib with the GRIB file seek method and in the Julia GRIB
        #  package, in Julia seek seeks through the messages themselves not
        #  the actual offset values. Here we use the cumulative sum of the
        #  message lengths to work out which message an offset value is in.
        message_length_cumsum = cumsum(index.message_lengths)
        offset_message_index = findfirst(message_length_cumsum .> first_offset) - 1
        seek(file, offset_message_index)
        return Message(file)
    end
end


function filter_offsets(index::FileIndex; query...)
    filtered_offsets = Array{Pair{Any,Any},1}()

    for (header_values, offset_values) in index.offsets
        for (k, v) in query
            if ismissing(header_values[k]) && ismissing(v)
                append!(filtered_offsets, [Pair(header_values, offset_values)])
            elseif ismissing(header_values[k]) || header_values[k] != v
                break
            else
                append!(filtered_offsets, [Pair(header_values, offset_values)])
            end
        end
    end

    return filtered_offsets
end

function filter(index::FileIndex; query...)::FileIndex
    filtered_offsets = filter_offsets(index; query...)

    filtered_index = deepcopy(index)
    filtered_index.offsets = filtered_offsets
    filtered_index.filter_by_keys = query

    get_header_values!(filtered_index)

    return filtered_index
end

function filter!(index::FileIndex; query...)
    filtered_offsets = filter_offsets(index; query...)

    index.offsets = filtered_offsets
    index.filter_by_keys = query

    get_header_values!(index)
end
