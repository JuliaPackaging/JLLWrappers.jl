function declare_old_executable_product(product_name)
    path_name = Symbol(string(product_name, "_path"))
    return quote
        # This is the old-style `withenv()`-based function
        function $(product_name)(f::Function; adjust_PATH::Bool = true, adjust_LIBPATH::Bool = true)
            # We sub off to a shared function to avoid compiling the same thing over and over again
            return Base.invokelatest(
                JLLWrappers.withenv_executable_wrapper,
                f,
                $(Symbol("$(product_name)_path")),
                PATH[],
                LIBPATH[],
                adjust_PATH,
                adjust_LIBPATH,
            )
        end

        # This will eventually be replaced with a `Ref{String}`
        $(path_name) = ""
        function $(Symbol(string("get_", product_name, "_path")))()
            return $(path_name)::String
        end
    end
end

function declare_new_executable_product(product_name)
    @static if VERSION < v"1.6.0-DEV"
        return nothing
    else
        path_name = Symbol(string(product_name, "_path"))
        return quote
            # This is the new-style `addenv()`-based function
            function $(product_name)(; adjust_PATH::Bool = true, adjust_LIBPATH::Bool = true)
                env = Base.invokelatest(
                    JLLWrappers.adjust_ENV!,
                    copy(ENV),
                    PATH[],
                    LIBPATH[],
                    adjust_PATH,
                    adjust_LIBPATH,
                )
                return Cmd(Cmd([$(path_name)]); env)
            end

            # Signal to concerned parties that they should use the new version, eventually.
            #@deprecate $(product_name)(func) $(product_name)()
        end
    end
end

macro declare_executable_product(product_name)
    return excat(
        # We will continue to support `withenv`-style for as long as we must
        declare_old_executable_product(product_name),
        # We will, however, urge users to move to the thread-safe `addenv`-style on Julia 1.6+
        declare_new_executable_product(product_name),
    )
end

macro init_executable_product(product_name, product_path)
    path_name = Symbol(string(product_name, "_path"))
    return esc(quote
        # Locate the executable on-disk, store into $(path_name)
        global $(path_name) = joinpath(artifact_dir, $(product_path))

        # Add this executable's directory onto the list of PATH's that we'll need to expose to dependents
        push!(PATH_list, joinpath(artifact_dir, $(dirname(product_path))))
    end)
end
