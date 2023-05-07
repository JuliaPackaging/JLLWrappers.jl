## JLLWrappers musl SONAME workaround
#
# The problem is detailed in this thread [0], but in short:
#
# JLLs rely on a specific behavior of most `dlopen()` implementations; that if
# a library with the same SONAME will not be loaded twice; e.g. if you first
# load `/a/libfoo.so`, loading `/b/libbar.so` which declares a dependency on
# `libfoo.so` will find the previously-loaded `libfoo.so` without needing to
# search because the SONAME `libbar.so` looks for matches the SONAME of the
# previously-loaded `libfoo.so`.  This allows JLLs to store libraries all over
# the place, and directly `dlopen()` all dependencies before any dependents
# would trigger a system-wide search.
#
# Musl does not do this.  They do have a mechanism for skipping the directory
# search, but it is only invoked when loading a library without specifying
# the full path [1].  This means that when checking for dependencies, musl
# skips all libraries that were loaded by full path [2].  All that needs to
# happen is that musl needs to record the `shortname` (e.g. SONAME) of all
# libraries, but sadly there's no way to do that if we also want to specify
# the library unambiguously [3,2].  Manipulating the environment to allow for
# non-fully-specified searches to work (e.g. changing `LD_LIBRARY_PATH` then
# invoking `dlopen("libfoo.so")`) won't work, as the environment is only read
# at process initialization.  We are therefore backed into a corner and must
# resort to heroic measures: manually inserting an appropriate `shortname`.
#
# [0] https://github.com/JuliaLang/julia/issues/40556
# [1] https://github.com/ifduyue/musl/blob/aad50fcd791e009961621ddfbe3d4c245fd689a3/ldso/dynlink.c#L1163-L1164
# [2] https://github.com/ifduyue/musl/blob/aad50fcd791e009961621ddfbe3d4c245fd689a3/ldso/dynlink.c#L1047-L1052
# [3] https://github.com/ifduyue/musl/blob/aad50fcd791e009961621ddfbe3d4c245fd689a3/ldso/dynlink.c#L1043-L1044

using Libdl

# Use this to ensure the GC doesn't clean up values we insert into musl.
manual_gc_roots = String[]

## We define these structures so that Julia's internal struct padding logic
## can do some arithmetic for us, instead of us needing to do manual offset
## calculation ourselves, which is more error-prone.


# Define ELF program header structure, depending on our bitwidth
@static if Sys.WORD_SIZE == 32
    struct Elf_Phdr
        p_type::UInt32
        p_offset::UInt32
        p_vaddr::UInt32
        p_paddr::UInt32
        p_filesz::UInt32
        p_memsz::UInt32
        p_flags::UInt32
        p_align::UInt32
    end
    struct ELF_DynEntry
        d_tag::UInt32
        # We drop the `d_un` union, and use only `d_val`, omitting `d_ptr`.
        d_val::UInt32
    end
    else
    struct Elf_Phdr
        p_type::UInt32
        p_flags::UInt32
        p_offset::UInt64
        p_vaddr::UInt64
        p_paddr::UInt64
        p_filesz::UInt64
        p_memsz::UInt64
        p_align::UInt64
    end
    struct ELF_DynEntry
        d_tag::UInt64
        # We drop the `d_un` union, and use only `d_val`, omitting `d_ptr`.
        d_val::UInt64
    end
end

# Taken from `include/elf.h`
# https://github.com/ifduyue/musl/blob/aad50fcd791e009961621ddfbe3d4c245fd689a3/include/elf.h#L595
const PT_DYNAMIC = 2
# Taken from `include/elf.h`
#https://github.com/ifduyue/musl/blob/aad50fcd791e009961621ddfbe3d4c245fd689a3/include/elf.h#L735
const DT_SONAME = 14
const DT_STRTAB = 5

# This structure taken from `libc.h`
# https://github.com/ifduyue/musl/blob/aad50fcd791e009961621ddfbe3d4c245fd689a3/src/internal/libc.h#L14-L18
struct musl_tls_module
    next::Ptr{musl_tls_module}
    image::Ptr{musl_tls_module}
    len::Csize_t
    size::Csize_t
    align::Csize_t
    offset::Csize_t
end

abstract type musl_dso end
include(joinpath(@__DIR__, "musl_abi/dso_v1.2.2.jl"))
include(joinpath(@__DIR__, "musl_abi/dso_v1.1.24.jl"))
include(joinpath(@__DIR__, "musl_abi/dso_v1.1.22.jl"))
include(joinpath(@__DIR__, "musl_abi/dso_v1.1.17.jl"))
include(joinpath(@__DIR__, "musl_abi/dso_v1.1.13.jl"))
include(joinpath(@__DIR__, "musl_abi/dso_v1.1.12.jl"))
include(joinpath(@__DIR__, "musl_abi/dso_v1.1.9.jl"))
include(joinpath(@__DIR__, "musl_abi/dso_v1.1.3.jl"))

function get_musl_dso_type(musl_version::VersionNumber)
    if musl_version >= v"1.2.2"
        return musl_dso_v1_2_2
    elseif musl_version >= v"1.1.24"
        return musl_dso_v1_1_24
    elseif musl_version >= v"1.1.22"
        return musl_dso_v1_1_22
    elseif musl_version >= v"1.1.17"
        return musl_dso_v1_1_17
    elseif musl_version >= v"1.1.13"
        return musl_dso_v1_1_13
    elseif musl_version >= v"1.1.12"
        return musl_dso_v1_1_12
    elseif musl_version >= v"1.1.10"
        # I guess v1.1.9's changes didn't stick.  :P
        return musl_dso_v1_1_3
    elseif musl_version >= v"1.1.9"
        return musl_dso_v1_1_9
    elseif musl_version >= v"1.1.3"
        return musl_dso_v1_1_3
    else
        return nothing
    end
end

_musl_version = Ref{Union{Nothing,VersionNumber}}(nothing)
function get_musl_version()
    if _musl_version[] !== nothing
        return _musl_version[]
    end

    stderr = IOBuffer()
    run(pipeline(ignorestatus(`/lib/libc.musl-x86_64.so.1 --version`); stdout=Base.devnull, stderr))

    for line in split(String(take!(stderr)), "\n")
        if startswith(line, "Version ")
            _musl_version[] = parse(VersionNumber, line[9:end])
        end
    end
    return _musl_version[]
end

function parse_soname(dso::musl_dso)
    soname_offset = nothing
    strtab_addr = nothing

    for idx in 1:dso.phnum
        phdr = unsafe_load(Ptr{Elf_Phdr}(dso.phdr), idx)
        if phdr.p_type == PT_DYNAMIC
            @debug("Found dynamic section", idx, phdr.p_vaddr, phdr.p_memsz)
            dyn_entries = Ptr{ELF_DynEntry}(phdr.p_vaddr + dso.base)
            num_dyn_entries = div(phdr.p_memsz, sizeof(ELF_DynEntry))
            for dyn_idx in 1:num_dyn_entries
                de = unsafe_load(dyn_entries, dyn_idx)
                if de.d_tag == DT_SONAME
                    @debug("Found SONAME dynamic entry!", de.d_tag, de.d_val)
                    soname_offset = de.d_val
                elseif de.d_tag == DT_STRTAB
                    @debug("Found STRTAB dynamic entry!", de.d_tag, de.d_val)
                    strtab_addr = Ptr{UInt8}(de.d_val + dso.base)
                end
            end
        end
    end

    if strtab_addr !== nothing && soname_offset !== nothing
        soname = unsafe_string(strtab_addr + soname_offset)
        @debug("Found SONAME entry", soname)
        return soname
    end
    return nothing
end

function replace_musl_shortname(lib_handle::Ptr{Cvoid})
    # First, find the absolute path of the library we're talking about
    lib_path = abspath(dlpath(lib_handle))

    # Load the DSO object, which conveniently is the handle that `dlopen()`
    # itself passes back to us.  Check to make sure it's what we expect, by
    # inspecting the `name` field.  If it's not, something has gone wrong,
    # and we should stop before touching anything else.
    musl_version = get_musl_version()
    if musl_version === nothing
        @debug("Unable to auto-detect musl version!", musl_version)
        return lib_handle
    end
    @debug("Auto-detected musl version", version=musl_version)

    dso_type = get_musl_dso_type(musl_version)
    if dso_type === nothing
        @debug("Unsupported musl ABI version", musl_version)
        return lib_handle
    end
    dso = unsafe_load(Ptr{dso_type}(lib_handle))
    dso_name = abspath(unsafe_string(dso.name))
    if dso_name != lib_path
        @debug("Unable to synchronize to DSO structure", name=dso_name, path=lib_path)
        return lib_handle
    end

    # If the shortname is not NULL, break out.
    if dso.shortname != C_NULL
        @debug("shortname != NULL!", name=dso_name, ptr=dso.shortname, value=unsafe_string(dso.shortname))
        return lib_handle
    end

    # Calculate the offset of `shortname` from the base pointer of the DSO object
    shortname_offset = fieldoffset(dso_type, findfirst(==(:shortname), fieldnames(dso_type)))

    # Replace the shortname with the SONAME of this loaded ELF object.  If it does not
    # exist, use the basename() of the library.
    new_shortname = something(parse_soname(dso), basename(lib_path))
    push!(manual_gc_roots, new_shortname)
    unsafe_store!(Ptr{Ptr{UInt8}}(lib_handle + shortname_offset), pointer(new_shortname))
    @debug("musl workaround successful", name=dso_name, shortname=new_shortname)
    return lib_handle
end
