macro declare_file_product(product_name)
    path_name = Symbol(string(product_name, "_path"))
    return esc(quote
        # These will be filled in by init_file_product()
        $(path_name) = ""
        $(product_name) = ""
    end)
end

macro init_file_product(product_name, product_path)
    path_name = Symbol(string(product_name, "_path"))
    return esc(quote
        # FileProducts are very simple, and we maintain the `_path` suffix version for consistency
        global $(path_name) = joinpath(artifact_dir, $(product_path))
        global $(product_name) = $(path_name)
    end)
end