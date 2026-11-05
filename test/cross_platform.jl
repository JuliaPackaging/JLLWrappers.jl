using Test, JLLWrappers
using Base.BinaryPlatforms: Platform

const CrossFoo_jll = joinpath(@__DIR__, "CrossFoo_jll")   # a package directory; product_paths also takes the loaded module

@testset "product_paths for a non-host platform" begin
    @test JLLWrappers.product_paths(CrossFoo_jll, Platform("x86_64", "linux"; libc = "glibc")) == Dict(:libfoo => "lib/libfoo.so")
    @test JLLWrappers.product_paths(CrossFoo_jll, Platform("aarch64", "macos")) == Dict{Symbol,String}()
    if haskey(Base.BinaryPlatforms.arch_mapping, "wasm32")
        p = Platform("wasm32", "wasi"; os_version = v"1")
        @test endswith(JLLWrappers.wrapper_file(CrossFoo_jll, p), "wasm32-unknown-wasip1.jl")
        @test JLLWrappers.product_paths(CrossFoo_jll, p) == Dict(:libfoo => "lib/libfoo.a")
        @test JLLWrappers.product_paths(CrossFoo_jll, Platform("wasm32", "wasi")) == Dict(:libfoo => "lib/libfoo.a")
    else
        # without wasm in Base, a wasm wrapper is invisible, as it is to loading
        @test JLLWrappers.product_paths(CrossFoo_jll, Platform("wasm32", "wasi")) == Dict{Symbol,String}()
    end
end
