#=
struct dso {
#if DL_FDPIC
	struct fdpic_loadmap *loadmap;
#else
	unsigned char *base;
#endif
	char *name;
	size_t *dynv;
	struct dso *next, *prev;

	Phdr *phdr;
	int phnum;
	size_t phentsize;
	int refcnt;
	Sym *syms;
	Elf_Symndx *hashtab;
	uint32_t *ghashtab;
	int16_t *versym;
	char *strings;
	unsigned char *map;
	size_t map_len;
	dev_t dev;
	ino_t ino;
	signed char global;
	char relocated;
	char constructed;
	char kernel_mapped;
	struct dso **deps, *needed_by;
	char *rpath_orig, *rpath;
	struct tls_module tls;
	size_t tls_id;
	size_t relro_start, relro_end;
	void **new_dtv;
	unsigned char *new_tls;
	volatile int new_dtv_idx, new_tls_idx;
	struct td_index *td_index;
	struct dso *fini_next;
	char *shortname;
#if DL_FDPIC
	unsigned char *base;
#else
	struct fdpic_loadmap *loadmap;
#endif
	struct funcdesc {
		void *addr;
		size_t *got;
	} *funcdescs;
	size_t *got;
	char buf[];
};
=#

struct musl_dso_v1_1_13 <: musl_dso
    # Things we find mildly interesting
    base::Ptr{Cvoid}
    name::Ptr{UInt8}

    # The wasteland of things we don't care about
    dynv::Ptr{Csize_t}
    next::Ptr{musl_dso}
    prev::Ptr{musl_dso}

    phdr::Ptr{Elf_Phdr}
    phnum::Cint
    phentsize::Csize_t
    refcount::Cint

    syms::Ptr{Cvoid}
    hashtab::Ptr{Cvoid}
    ghashtab::Ptr{Cvoid}
    versym::Ptr{Int16}
    strings::Ptr{UInt8}
    lazy::Ptr{Csize_t}
    lazy_cnt::Csize_t

    map::Ptr{Cuchar}
    map_len::Csize_t

    # We assume that dev_t and ino_t are always `uint64_t`, even on 32-bit systems.
    dev::UInt64
    ino::UInt64
    dso_global::Cchar
    relocated::Cchar
    constructed::Cchar
    kernel_mapped::Cchar
    # NOTE: struct layout rules should insert 5 bytes of space here
    deps::Ptr{Ptr{musl_dso}}
    needed_by::Ptr{musl_dso}
    rpath_orig::Ptr{UInt8}
    rpath::Ptr{UInt8}

    tls::musl_tls_module
    tls_id::Csize_t
    relro_start::Csize_t
    relro_end::Csize_t
    new_dtv::Ptr{Ptr{Cuint}}
    new_tls::Ptr{UInt8}
    new_dtv_idx::Cint
    new_tls_idx::Cint
    td_index::Ptr{Cvoid}
    fini_next::Ptr{musl_dso}

    # Finally!  The field we're interested in!
    shortname::Ptr{UInt8}

    # We'll put this stuff at the end because it might be interesting to someone somewhere
    loadmap::Ptr{Cvoid}
    funcdesc::Ptr{Cvoid}
    got::Ptr{Csize_t}
end
