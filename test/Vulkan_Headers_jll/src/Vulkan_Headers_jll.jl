# Use baremodule to shave off a few KB from the serialized `.ji` file
baremodule Vulkan_Headers_jll
using Base
using Base: UUID
import JLLWrappers

JLLWrappers.@generate_main_file_header("Vulkan_Headers")
JLLWrappers.@generate_main_file("Vulkan_Headers", UUID("8d446b21-f3ad-5576-a034-752265b9b6f9"))
end  # module Vulkan_Headers_jll
