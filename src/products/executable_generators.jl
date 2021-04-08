function declare_old_executable_product(product_name)
    path_name = Symbol(string(product_name, "_path"))
    return quote
        # This is the old-style `withenv()`-based function
        """
            $($product_name)(f::Function; adjust_PATH::Bool=true, adjust_LIBPATH::Bool=true)

        An `ExecutableProduct` wrapper that supports the execution of $($product_name).

        # Example
        ```julia
        $($product_name)() do exe
            run(`\$exe \$arguments`)
        end
        ```

        !!! compat "Julia 1.3"
        """
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
            @doc """
                $($product_name)(; adjust_PATH::Bool=true, adjust_LIBPATH::Bool=true) -> Cmd

            An `ExecutableProduct` wrapper that supports the execution of $($product_name).
            This wrapper is thread-safe and should be preferred on Julia 1.6+.

            # Example
            ```julia
            run(`\$($($product_name)()) \$arguments`)
            ```

            !!! compat "Julia 1.6"
            """
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
    path_name = string(product_name, "_path")
    return excat(
        # We will continue to support `withenv`-style for as long as we must
        declare_old_executable_product(product_name),
        # We will, however, urge users to move to the thread-safe `addenv`-style on Julia 1.6+
        declare_new_executable_product(product_name),
        # Perform a compile-time load of a path preference override
        :($(Symbol(path_name)) = $(emit_preference_path_load(path_name))),
    )
end

macro init_executable_product(product_name, product_path)
    path_name = Symbol(string(product_name, "_path"))
    return esc(quote
        global $(path_name)
        # Locate the executable on-disk, store into $(path_name)
        if $(path_name) === nothing
            $(path_name) = joinpath(artifact_dir, $(product_path))
        end

        # Add this executable's directory onto the list of PATH's that we'll need to expose to dependents
        push!(PATH_list, dirname($(path_name)))
    end)
end
