# Reading a JLL for a platform other than the host, without loading anything: for tools that
# cross-compile against a JLL, such as a linker taking the static archives of a wasm build.

@static if VERSION >= v"1.6.0-DEV"
using Base.BinaryPlatforms: AbstractPlatform, Platform, select_platform

"""
    wrapper_file(jll::Union{Module,AbstractString}, platform::AbstractPlatform) -> Union{String,Nothing}

The generated wrapper of `jll` (the package, or its directory) that `platform` would load: `src/wrappers/<triplet>.jl`, or
`any.jl`, or `nothing`. Wrapper names this Julia cannot parse as a platform are skipped, as when
loading.
"""
wrapper_file(jll::Module, platform::AbstractPlatform) = wrapper_file(pkgdir(jll), platform)
function wrapper_file(pkg::AbstractString, platform::AbstractPlatform)
    dir = joinpath(pkg, "src", "wrappers")
    isdir(dir) || return nothing
    files = filter(f -> endswith(f, ".jl"), readdir(dir))
    "any.jl" in files && return joinpath(dir, "any.jl")
    wrappers = Dict{Platform,String}()
    for f in files
        p = tryparse(Platform, f[1:end-3])
        p === nothing || (wrappers[p] = joinpath(dir, f))
    end
    return select_platform(wrappers, platform)
end

"""
    product_paths(jll::Union{Module,AbstractString}, platform::AbstractPlatform) -> Dict{Symbol,String}

The products of `jll` for `platform`, each a path relative to that platform's artifact, read from
the wrapper `platform` would load (see [`wrapper_file`](@ref)) without evaluating it. Empty when
`jll` has no build for `platform`.
"""
function product_paths(jll::Union{Module,AbstractString}, platform::AbstractPlatform)
    file = wrapper_file(jll, platform)
    out = Dict{Symbol,String}()
    file === nothing && return out
    inits = (Symbol("@init_library_product"), Symbol("@init_file_product"), Symbol("@init_executable_product"))
    function walk(ex)
        ex isa Expr || return
        if ex.head === :macrocall
            name = ex.args[1]
            name = name isa Expr && name.head === :. ? name.args[end].value : name
            if name in inits
                args = filter(a -> !(a isa LineNumberNode), ex.args[2:end])
                length(args) >= 2 && args[1] isa Symbol && args[2] isa String && (out[args[1]] = args[2])
            end
        end
        foreach(walk, ex.args)
    end
    walk(Meta.parseall(read(file, String); filename = file))
    return out
end

"""
    artifact_toml(jll::Module) -> String

The `Artifacts.toml` of `jll`, for `Artifacts.artifact_meta(name, toml; platform)` and
`Pkg.Artifacts.ensure_artifact_installed(name, toml; platform)` with a non-host `platform`.
"""
artifact_toml(jll::Module) = joinpath(pkgdir(jll), "Artifacts.toml")
end
