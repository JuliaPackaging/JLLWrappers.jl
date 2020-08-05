module JLLWrappers

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 0
end

using Pkg, Pkg.BinaryPlatforms, Pkg.Artifacts, Libdl
import Base: UUID

export get_artifacts_toml,
    get_artifacts,
    get_platforms,
    cleanup_platforms!,
    select_best_platform,
    cleanup_best_platform,
    executable_wrapper,
    initialize_path_list!,
    get_lib_path_handle!,
    get_exe_path!,
    cleanup_path_libpath!

##### Functions used in the entry point of the package to select the platform

function get_artifacts_toml(dir::AbstractString, rest...; kwargs...)
    return joinpath(dir, "..", "Artifacts.toml")
end

function get_artifacts(artifacts_toml::AbstractString, pkg_uuid::UUID, rest...; kwargs...)
    return Pkg.Artifacts.load_artifacts_toml(artifacts_toml; pkg_uuid=pkg_uuid)
end

function get_platforms(jll_name::AbstractString,
                       artifacts_toml::AbstractString,
                       artifacts::Dict,
                       rest...;
                       kwargs...)
    return [Pkg.Artifacts.unpack_platform(e, jll_name, artifacts_toml) for e in artifacts[jll_name]]
end

function cleanup_platforms!(dir, platforms::AbstractVector{<:Platform}, rest...; kwargs...)
    # In old versions of Julia armv7l used to be called simply arm, rename it
    filter!(p -> isfile(joinpath(dir, "wrappers", replace(triplet(p), "arm-" => "armv7l-") * ".jl")), platforms)
end

function select_best_platform(platforms::AbstractVector{<:Platform}, rest...; kwargs...)
    return select_platform(Dict(p => triplet(p) for p in platforms))
end

function cleanup_best_platform(best_platform::AbstractString, rest...; kwargs...)
    # In old versions of Julia armv7l used to be called simply arm, rename it
    return replace(best_platform, "arm-" => "armv7l-")
end

##### Functions used in the wrapper

function executable_wrapper(f::Function,
                            executable_path::AbstractString,
                            PATH::AbstractString,
                            LIBPATH::AbstractString,
                            LIBPATH_env::AbstractString,
                            LIBPATH_default::AbstractString,
                            adjust_PATH::Bool,
                            adjust_LIBPATH::Bool,
                            path_separator::Char,
                            rest...;
                            kwargs...)

    env_mapping = Dict{String,String}()
    if adjust_PATH
        if !isempty(get(ENV, "PATH", ""))
            env_mapping["PATH"] = string(PATH, path_separator, ENV["PATH"])
        else
            env_mapping["PATH"] = PATH
        end
    end
    if adjust_LIBPATH
        LIBPATH_base = get(ENV, LIBPATH_env, expanduser(LIBPATH_default))
        if !isempty(LIBPATH_base)
            env_mapping[LIBPATH_env] = string(LIBPATH, path_separator, LIBPATH_base)
        else
            env_mapping[LIBPATH_env] = LIBPATH
        end
    end
    withenv(env_mapping...) do
        f(executable_path)
    end
end

function initialize_path_list!(PATH_list::AbstractVector{<:AbstractString},
                               list_of_path_lists,
                               rest...;
                               kwargs...)
    foreach(p -> append!(PATH_list, p), list_of_path_lists)
end

function get_lib_path_handle!(LIBPATH_list::AbstractVector{<:AbstractString},
                              artifact_dir::AbstractString,
                              lib_splitpath::AbstractVector{<:AbstractString},
                              rest...;
                              kwargs...)
    lib_path = normpath(joinpath(artifact_dir, lib_splitpath...))
    # Manually `dlopen()` this right now so that future invocations
    # of `ccall` with its `SONAME` will find this path immediately.
    handle = dlopen(lib_path)
    push!(LIBPATH_list, dirname(lib_path))
    return lib_path, handle
end

function get_exe_path!(PATH_list::AbstractVector{<:AbstractString},
                       artifact_dir::AbstractString,
                       exe_splitpath::AbstractVector{<:AbstractString},
                       rest...;
                       kwargs...)
    exe_path = normpath(joinpath(artifact_dir, exe_splitpath...))
    push!(PATH_list, dirname(exe_path))
    return exe_path
end

function cleanup_path_libpath!(PATH_list::AbstractVector{<:AbstractString},
                               LIBPATH_list::AbstractVector{<:AbstractString},
                               path_separator::Char,
                               rest...;
                               kwargs...)
    # Filter out duplicate and empty entries in our PATH and LIBPATH entries
    filter!(!isempty, unique!(PATH_list))
    filter!(!isempty, unique!(LIBPATH_list))
    path = join(PATH_list, path_separator)
    libpath = join(vcat(LIBPATH_list, [joinpath(Sys.BINDIR, Base.LIBDIR, "julia"), joinpath(Sys.BINDIR, Base.LIBDIR)]), path_separator)
    return path, libpath
end

end # module
