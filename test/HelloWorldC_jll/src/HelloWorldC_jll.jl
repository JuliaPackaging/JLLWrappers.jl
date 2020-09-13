# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule HelloWorldC_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("HelloWorldC")
JLLWrappers.@generate_main_file("HelloWorldC", UUID("dca1746e-5efc-54fc-8249-22745bc95a49"))
end  # module HelloWorldC_jll
