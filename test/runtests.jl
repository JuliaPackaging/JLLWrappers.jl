using JLLWrappers
using Pkg
using Test

module TestJLL end

@testset "JLLWrappers.jl" begin
    mktempdir() do dir
        Pkg.activate(dir)
        # Package with a FileProduct
        Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "Vulkan_Headers_jll")))
        @test_nowarn @eval TestJLL using Vulkan_Headers_jll
        @test @eval TestJLL Vulkan_Headers_jll.is_available()
        @test isfile(@eval TestJLL vk_xml)
        # Package with an ExecutableProduct
        Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "HelloWorldC_jll")))
        @test_nowarn @eval TestJLL using HelloWorldC_jll
        @test @eval TestJLL HelloWorldC_jll.is_available()
        @test "Hello, World!" == @eval TestJLL hello_world(h->readchomp(`$h`))
        # Package with a LibraryProduct
        Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "OpenLibm_jll")))
        @test_nowarn @eval TestJLL using OpenLibm_jll
        @test @eval TestJLL OpenLibm_jll.is_available()
        @test exp(3.14) ≈ @eval TestJLL ccall((:exp, libopenlibm), Cdouble, (Cdouble,), 3.14)
    end
end
