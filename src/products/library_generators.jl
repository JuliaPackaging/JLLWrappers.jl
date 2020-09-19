
function declare_old_library_product(product_name, product_soname)
    handle_name = Symbol(string(product_name, "_handle"))
    path_name = Symbol(string(product_name, "_path"))
    return esc(quote
        # This will be filled in by init_library_product()
        $(handle_name) = C_NULL
        $(path_name) = ""

        # On Julia 1.5-, this must be `const` and must be the SONAME
        const $(product_name) = $(product_soname)
    end)
end

function declare_new_library_product(product_name)
    handle_name = Symbol(string(product_name, "_handle"))
    path_name = Symbol(string(product_name, "_path"))
    return esc(quote
        # These will be filled in by init_library_product()
        $(handle_name) = C_NULL
        $(path_name) = ""

        # On Julia 1.6+, this doesn't have to be `const`!  Thanks Jeff!
        $(product_name) = ""
    end)
end

macro declare_library_product(product_name, product_soname)
    @static if VERSION < v"1.6.0-DEV"
        return declare_old_library_product(product_name, product_soname)
    else
        return declare_new_library_product(product_name)
    end
end

function init_new_library_product(product_name)
    @static if VERSION < v"1.6.0-DEV"
        return nothing
    else
        return quote
            # Initialize non-const variable export with the path to this product
            global $(product_name) = $(Symbol(string(product_name, "_path")))
        end
    end
end

macro init_library_product(product_name, product_path, dlopen_flags)
    handle_name = Symbol(string(product_name, "_handle"))
    path_name = Symbol(string(product_name, "_path"))
    return excat(quote
            global $(path_name) = joinpath(artifact_dir, $(product_path))
            # Manually `dlopen()` this right now so that future invocations
            # of `ccall` with its path/SONAME will find this path immediately.
            global $(handle_name) = dlopen($(path_name), $(dlopen_flags))
            push!(LIBPATH_list, joinpath(artifact_dir, $(dirname(product_path))))
        end,
        init_new_library_product(product_name),
    )
end
