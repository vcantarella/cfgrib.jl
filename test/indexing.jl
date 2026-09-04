using DataStructures

#  Dummy offsets for testing
function dummy_offsets()
    message1 = (
        int    = 10,
        array  = [1,2,3],
        string = "potato",
        ignored = "☹️",
        absent = missing,
        one_here = 20
    )

    message2 = (
        int    = 10,
        array  = [1,2,3,5],
        string = "cabbage",
        absent = missing,
        one_here = missing
    )

    dummy_offsets = OrderedDict(
        message1 => 0,
        message2 => 10_000
    )

    return dummy_offsets
end

#  Dummy FileIndex for testing
function dummy_file_index()
    fileindex = CfGRIB.FileIndex()

    fileindex.grib_path = "./dummy-path.grib"

    fileindex.index_keys = ["int", "array", "string", "absent", "one_here"]
    fileindex.offsets = collect(pairs(dummy_offsets()))

    return fileindex
end

dfi = dummy_file_index()

#  When new fields are added, add any new required tests and then
#  add the field to this list
@test fieldnames(CfGRIB.FileIndex) == (
    :allowed_protocol_version, :grib_path, :index_path, :index_keys, :offsets,
    :message_lengths, :header_values, :filter_by_keys
)

#  If this fails, check that any changes to the code are
#  reflected in the tests
@test dfi.allowed_protocol_version == v"0.0.0"

#  These should not be initialised yet
@test ! isdefined(dfi, :index_path)
@test ! isdefined(dfi, :header_values)
@test ! isdefined(dfi, :filter_by_keys)

#  Stable across Julia versions, changes only with the keys or protocol version
CfGRIB.index_path!(dfi)
@test dfi.index_path == "./dummy-path.grib.7282912749778f4b.idx"

CfGRIB.get_header_values!(dfi)
expected_header_values = OrderedDict(
    "int"      => [10],
    "array"    => Array{Int64,1}[[1, 2, 3], [1, 2, 3, 5]],
    "string"   => ["potato", "cabbage"],
    "absent"   => Missing[missing],
    "one_here" => Union{Missing, Int64}[20, missing]
)
@test isequal(dfi.header_values, expected_header_values)

@testset begin
    test_file = joinpath(dir_testfiles, "era5-levels-members.grib")

    index = CfGRIB.FileIndex(
        test_file,
        CfGRIB.ALL_KEYS
    )

    message = CfGRIB.first(index)

    CfGRIB.filter!(index, paramId=130)
end

@testset "index file cache" begin
    mktempdir() do dir
        grib = joinpath(dir, "era5-levels-members.grib")
        cp(joinpath(dir_testfiles, "era5-levels-members.grib"), grib)

        #  First open scans the GRIB and writes the cache next to it
        fresh = CfGRIB.FileIndex(grib, CfGRIB.ALL_KEYS)
        @test isfile(fresh.index_path)

        #  Second open comes from the cache and must be indistinguishable
        cached = CfGRIB.FileIndex(grib, CfGRIB.ALL_KEYS)
        @test isequal(cached.offsets, fresh.offsets)
        @test cached.message_lengths == fresh.message_lengths
        @test isequal(cached.header_values, fresh.header_values)

        #  A changed GRIB invalidates the cache
        open(io -> write(io, 0x00), grib, "a")
        stale = CfGRIB.FileIndex()
        stale.grib_path = grib
        stale.index_keys = CfGRIB.ALL_KEYS
        @test !CfGRIB.from_indexfile!(stale)

        #  Garbage is ignored rather than fatal
        write(fresh.index_path, "not an index")
        @test !CfGRIB.from_indexfile!(stale)
    end
end
