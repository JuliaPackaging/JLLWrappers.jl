# Note: This file is executed from `Pkg` in an isolated environment.
# Warn: Since this is executed in a sandbox, the current preferences are not
#       propagated and thus no decision can be made based on them.
#       Use LazyArtifacts in this case.
#       Fixed in https://github.com/JuliaLang/Pkg.jl/pull/2920

push!(Base.LOAD_PATH, dirname(@__DIR__))
using TOML, Artifacts, Base.BinaryPlatforms
include("./platform_augmentation.jl")
artifacts_toml = joinpath(dirname(@__DIR__), "Artifacts.toml")

# Get "target triplet" from ARGS, if given (defaulting to the host triplet otherwise)
target_triplet = get(ARGS, 1, Base.BinaryPlatforms.host_triplet())

# Augment this platform object with any special tags we require
platform = augment_platform!(HostPlatform(parse(Platform, target_triplet)))

# Select all downloadable artifacts that match that platform
artifacts = select_downloadable_artifacts(artifacts_toml; platform, include_lazy = true)

#Output the result to `stdout` as a TOML dictionary
TOML.print(stdout, artifacts)
