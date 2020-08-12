include("products/executable_generators.jl")
include("products/file_generators.jl")
include("products/library_generators.jl")

macro generate_init_header(dependencies...)
    deps_path_add = Expr[]
    if !isempty(dependencies)
        for dep in dependencies
            push!(deps_path_add, quote
                append!(PATH_list, $(dep).PATH_list)
                append!(LIBPATH_list, $(dep).LIBPATH_list)
            end)
        end
    end

    return excat(
        # This either calls `@artifact_str()`, or returns a constant string if we're overridden.
        :(global artifact_dir = find_artifact_dir()),

        # Initialize PATH_list and LIBPATH_list
        deps_path_add...,
    )
end


macro generate_init_footer()
    return esc(quote
        # Filter out duplicate and empty entries in our PATH and LIBPATH entries
        unique!(PATH_list)
        unique!(LIBPATH_list)
        global PATH = join(PATH_list, $(pathsep))
        global LIBPATH = join(vcat(LIBPATH_list, Base.invokelatest(JLLWrappers.get_julia_libpaths)), $(pathsep))
    end)
end