# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule LAMMPS_jll
using Base
using Base: UUID
using LazyArtifacts
include(path) = Base.include(@__MODULE__, path)
include(joinpath("..", ".pkg", "platform_augmentation.jl"))
import JLLWrappers

using Preferences

function known_abis()
    return (:MicrosoftMPI, :MPICH, :MPItrampoline)
end

const abi = @load_preference("abi", Sys.iswindows() ? :MicrosoftMPI : :MPICH)

function set_abi(abi)
    if abi ∉ known_abis()
        error("""
            The MPI ABI $abi is not supported.
            Please set the MPI ABI to one of the following:
            $(known_abis())
        """)
    end
    @set_preferences!("abi" => string(abi))
    @warn "The MPI abi has changed, you will need to restart Julia for the change to take effect" abi
    return abi
end

JLLWrappers.@generate_main_file_header("LAMMPS")
JLLWrappers.@generate_main_file("LAMMPS", UUID("5b3ab26d-9607-527c-88ea-8fe5ba57cafe"))
end  # module LAMMPS_jll
