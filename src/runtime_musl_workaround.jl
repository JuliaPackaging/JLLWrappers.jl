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

# This structure taken from `ldso/dynlink.c`
# https://github.com/ifduyue/musl/blob/aad50fcd791e009961621ddfbe3d4c245fd689a3/ldso/dynlink.c#L53-L107
struct musl_dso
    # Things we find mildly interesting
    base::Ptr{Cvoid}
    name::Ptr{UInt8}

    # The wasteland of things we don't care about
    dynv::Ptr{Csize_t}
    next::Ptr{musl_dso}
    prev::Ptr{musl_dso}

    phdr::Ptr{Cvoid}
    phnum::Cint
    phentsize::Csize_t

    syms::Ptr{Cvoid}
    hashtab::Ptr{Cvoid}
    ghashtab::Ptr{Cvoid}
    versym::Ptr{Int16}
    strings::Ptr{UInt8}
    syms_next::Ptr{musl_dso}
    lazy_next::Ptr{musl_dso}
    lazy::Ptr{Csize_t}
    lazy_cnt::Csize_t

    map::Ptr{Cuchar}
    map_len::Csize_t

    # We assume that dev_t and ino_t are always `uint64_t`, even on 32-bit systems.
    dev::UInt64
    ino::UInt64
    relocated::Cchar
    constructed::Cchar
    kernel_mapped::Cchar
    mark::Cchar
    bfs_built::Cchar
    runtime_loaded::Cchar
    # NOTE: struct layout rules should insert two bytes of space here
    deps::Ptr{Ptr{musl_dso}}
    needed_by::Ptr{musl_dso}
    ndeps_direct::Csize_t
    next_dep::Csize_t
    ctor_visitor::Cint
    rpath_orig::Ptr{UInt8}
    rpath::Ptr{UInt8}

    tls::musl_tls_module
    tls_id::Csize_t
    relro_start::Csize_t
    relro_end::Csize_t
    new_dtv::Ptr{Ptr{Cuint}}
    new_tls::Ptr{UInt8}
    td_index::Ptr{Cvoid}
    fini_next::Ptr{musl_dso}

    # Finally!  The field we're interested in!
    shortname::Ptr{UInt8}

    # We'll put this stuff at the end because it might be interesting to someone somewhere
    loadmap::Ptr{Cvoid}
    funcdesc::Ptr{Cvoid}
    got::Ptr{Csize_t}
end

function replace_musl_shortname(lib_handle::Ptr{Cvoid})
    # First, find the absolute path of the library we're talking about
    lib_path = abspath(dlpath(lib_handle))

    # Load the DSO object, which conveniently is the handle that `dlopen()`
    # itself passes back to us.  Check to make sure it's what we expect, by
    # inspecting the `name` field.  If it's not, something has gone wrong,
    # and we should stop before touching anything else.
    dso = unsafe_load(Ptr{musl_dso}(lib_handle))
    dso_name = abspath(unsafe_string(dso.name))
    if dso_name != lib_path
        @debug("Unable to synchronize to DSO structure", name=dso_name, path=lib_path)
        return lib_handle
    end

    # If the shortname is not NULL, break out.
    if dso.shortname != C_NULL
        @debug("shortname != NULL!", ptr=shortname_ptr, value=unsafe_string(shortname_ptr))
        return lib_handle
    end

    # Calculate the offset of `shortname` from the base pointer of the DSO object
    shortname_offset = fieldoffset(musl_dso, findfirst(==(:shortname), fieldnames(musl_dso)))

    # Replace the shortname with the basename of lib_path.  Note that, in general, this
    # should be the SONAME, but not always.  If we wanted to be pedantic, we should
    # actually parse out the SONAME of this object.  But we don't want to be.
    new_shortname = basename(lib_path)
    push!(manual_gc_roots, new_shortname)
    unsafe_store!(Ptr{Ptr{UInt8}}(lib_handle + shortname_offset), pointer(new_shortname))
    return lib_handle
end
