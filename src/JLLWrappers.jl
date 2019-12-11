module JLLWrappers

function executable_wrapper(f::Function, executable_path::AbstractString,
                            PATH::AbstractString, LIBPATH::AbstractString,
                            LIBPATH_env::AbstractString, rest...;
                            adjust_PATH::Bool = true, adjust_LIBPATH::Bool = true)
    env_mapping = Dict{String,String}()
    if adjust_PATH
        if !isempty(get(ENV, "PATH", ""))
            env_mapping["PATH"] = string(PATH, ':', ENV["PATH"])
        else
            env_mapping["PATH"] = PATH
        end
    end
    if adjust_LIBPATH
        if !isempty(get(ENV, LIBPATH_env, ""))
            env_mapping[LIBPATH_env] = string(LIBPATH, ':', ENV[LIBPATH_env])
        else
            env_mapping[LIBPATH_env] = LIBPATH
        end
    end
    withenv(env_mapping...) do
        f(executable_path)
    end
end

update_path_list!(path_list, list_of_path_lists) =
    foreach(p -> append!(path_list, p), list_of_path_lists)

end # module
