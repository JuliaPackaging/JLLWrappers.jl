module JLLWrappers

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
    @eval Base.Experimental.@optlevel 0
end

using Libdl

export executable_wrapper,
    initialize_path_list!,
    get_lib_path_handle!,
    get_exe_path!,
    cleanup_path_libpath!

function executable_wrapper(f::Function,
                            executable_path::AbstractString,
                            PATH::AbstractString,
                            LIBPATH::AbstractString,
                            LIBPATH_env::AbstractString,
                            LIBPATH_default::AbstractString,
                            adjust_PATH::Bool,
                            adjust_LIBPATH::Bool,
                            path_separator::Char,
                            )

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

initialize_path_list!(path_list, list_of_path_lists) =
    foreach(p -> append!(path_list, p), list_of_path_lists)

function get_lib_path_handle!(libpath_list, artifact_dir, lib_splitpath)
    lib_path = normpath(joinpath(artifact_dir, lib_splitpath...))
    # Manually `dlopen()` this right now so that future invocations
    # of `ccall` with its `SONAME` will find this path immediately.
    handle = dlopen(lib_path)
    push!(libpath_list, dirname(lib_path))
    return lib_path, handle
end

function get_exe_path!(path_list, artifact_dir, exe_splitpath)
    exe_path = normpath(joinpath(artifact_dir, exe_splitpath...))
    push!(path_list, dirname(exe_path))
    return exe_path
end

function cleanup_path_libpath!(path_list, libpath_list, path, libpath, path_separator)
    # Filter out duplicate and empty entries in our PATH and LIBPATH entries
    filter!(!isempty, unique!(path_list))
    filter!(!isempty, unique!(libpath_list))
    path = join(path_list, path_separator)
    libpath = join(vcat(libpath_list, [joinpath(Sys.BINDIR, Base.LIBDIR, "julia"), joinpath(Sys.BINDIR, Base.LIBDIR)]), path_separator)
    return path, libpath
end

end # module
