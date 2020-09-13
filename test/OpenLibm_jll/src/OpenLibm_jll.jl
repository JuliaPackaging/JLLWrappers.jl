# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule OpenLibm_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("OpenLibm")
JLLWrappers.@generate_main_file("OpenLibm", UUID("05823500-19ac-5b8b-9628-191a04bc5112"))
end  # module OpenLibm_jll
