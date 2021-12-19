using Base.BinaryPlatforms

function augment_platform!(platform)
    # Can't use Preferences since we might be running this very early with a non-existing Manifest
    LAMMPS_UUID = Base.UUID("5b3ab26d-9607-527c-88ea-8fe5ba57cafe")
    abi = get(Base.get_preferences(LAMMPS_UUID), "abi", Sys.iswindows() ? "microsoftmpi" : "mpich")
    if !haskey(platform, "mpi")
        platform["mpi"] = abi
    end
    return platform
end
