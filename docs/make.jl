using Documenter, CfGRIB

DocMeta.setdocmeta!(CfGRIB, :DocTestSetup, :(using CfGRIB); recursive=true)

makedocs(;
    modules=[CfGRIB],
    format=Documenter.HTML(;
        # Use clean URLs, unless built as a "local" build
        prettyurls=(!("local" in ARGS)),
        canonical="https://vcantarella.github.io/cfgrib.jl/stable/",
    ),
    sitename="CfGRIB.jl",
    pages=[
        "Home" => "index.md",
        "Manual" => Any[
            "In Depth Guide" => "man/guide.md",
            "ECMWF Forecasts" => "man/ecmwf-forecasts.md",
        ],
        "Library" => Any[
        # "Public" => "lib/public.md",
            "Internals" => map(
            s -> "lib/internals/$(s)",
            sort(readdir(joinpath(@__DIR__, "src/lib/internals"))),
        ),],
    ],
)

deploydocs(; repo="github.com/vcantarella/cfgrib.jl", devbranch="dev", push_preview=true)
