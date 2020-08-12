module JLLWrappers

# We need to glue expressions together a lot
function excat(exs::Union{Expr,Nothing}...)
    ex = Expr(:block)
    for exn in exs
        if exn !== nothing
            append!(ex.args, exn.args)
        end
    end
    return esc(ex)
end

include("toplevel_generators.jl")
include("wrapper_generators.jl")
include("runtime.jl")

end # module
