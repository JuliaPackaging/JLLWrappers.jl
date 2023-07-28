using JLLWrappers
using Pkg
using Test

# We use preferences only in Julia v1.6+
@static if VERSION >= v"1.6.0-DEV"
    using Preferences
end

module TestJLL end

@testset "JLLWrappers.jl" begin
    mktempdir() do dir
        Pkg.activate(dir)

        # actually use the development version of JLLWrappers
        Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "..")))

        # Prepare some overrides for various products
        @static if VERSION >= v"1.6.0-DEV"
            set_preferences!(joinpath(dir, "LocalPreferences.toml"), "Vulkan_Headers_jll", "vulkan_hpp_path" => "foo")
            set_preferences!(joinpath(dir, "LocalPreferences.toml"), "HelloWorldC_jll", "goodbye_world_path" => "goodbye")
            set_preferences!(joinpath(dir, "LocalPreferences.toml"), "OpenLibm_jll", "libnonexisting_path" => "libreallynonexisting")
        end

        # Package with a FileProduct
        Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "Vulkan_Headers_jll")))
        @test_nowarn @eval TestJLL using Vulkan_Headers_jll
        @test @eval TestJLL Vulkan_Headers_jll.is_available()
        @test isfile(@eval TestJLL vk_xml)
        @test isfile(@eval TestJLL Vulkan_Headers_jll.vk_xml_path)
        @test isfile(@eval TestJLL Vulkan_Headers_jll.get_vk_xml_path())
        @static if VERSION >= v"1.6.0-DEV"
            @test !isfile(@eval TestJLL vulkan_hpp)
            @test !isfile(@eval TestJLL Vulkan_Headers_jll.vulkan_hpp_path)
            @test !isfile(@eval TestJLL Vulkan_Headers_jll.get_vulkan_hpp_path())
        else
            @test isfile(@eval TestJLL vulkan_hpp)
            @test isfile(@eval TestJLL Vulkan_Headers_jll.vulkan_hpp_path)
            @test isfile(@eval TestJLL Vulkan_Headers_jll.get_vulkan_hpp_path())
        end
        @test isdir(@eval TestJLL Vulkan_Headers_jll.artifact_dir)
        @test isempty(@eval TestJLL Vulkan_Headers_jll.PATH[])
        @test occursin(Sys.BINDIR, @eval TestJLL Vulkan_Headers_jll.LIBPATH[])

        # Package with an ExecutableProduct
        Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "HelloWorldC_jll")))
        @test_nowarn @eval TestJLL using HelloWorldC_jll
        if Sys.isfreebsd()
            @test @eval TestJLL !HelloWorldC_jll.is_available()
        else
            @test @eval TestJLL HelloWorldC_jll.is_available()
            @test "Hello, World!" == @eval TestJLL hello_world(h->readchomp(`$h`))
            @test isfile(@eval TestJLL HelloWorldC_jll.hello_world_path)
            @test isfile(@eval TestJLL HelloWorldC_jll.get_hello_world_path())
            @test isdir(@eval TestJLL HelloWorldC_jll.artifact_dir)
            @test !isempty(@eval TestJLL HelloWorldC_jll.PATH[])
            @test occursin(Sys.BINDIR, @eval TestJLL HelloWorldC_jll.LIBPATH[])
            @test !isfile(@eval TestJLL HelloWorldC_jll.goodbye_world_path)
            @test !isfile(@eval TestJLL HelloWorldC_jll.get_goodbye_world_path())
            @static if VERSION >= v"1.6.0-DEV"
                @test basename(@eval TestJLL HelloWorldC_jll.get_goodbye_world_path()) == "goodbye"
            else
                @test basename(@eval TestJLL HelloWorldC_jll.get_goodbye_world_path()) == "goodbye_world"
            end

            @static if VERSION >= v"1.6.0"
                # Test old-style exe execution
                @test_logs (:warn, "hello_world() is deprecated, use the non-do-block form") begin
                    output = @eval TestJLL begin
                        hello_world() do exe
                            readchomp(`$(exe)`)
                        end
                    end
                end
                @test output == "Hello, World!"

                # Test new-style exe execution
                output = @eval TestJLL begin
                    readchomp(`$(hello_world())`)
                end
                @test output == "Hello, World!"
            else
                output = @eval TestJLL begin
                    hello_world() do exe
                        readchomp(`$(exe)`)
                    end
                end
                @test output == "Hello, World!"
            end
        end

        # Package with a LibraryProduct
        Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "OpenLibm_jll")))
        @test_nowarn @eval TestJLL using OpenLibm_jll
        @test @eval TestJLL OpenLibm_jll.is_available()
        @test exp(3.14) ≈ @eval TestJLL ccall((:exp, libopenlibm), Cdouble, (Cdouble,), 3.14)
        @test isfile(@eval TestJLL OpenLibm_jll.libopenlibm_path)
        @test isfile(@eval TestJLL OpenLibm_jll.get_libopenlibm_path())
        @test isdir(@eval TestJLL OpenLibm_jll.artifact_dir)
        @test isempty(@eval TestJLL OpenLibm_jll.PATH[])
        @test occursin(Sys.BINDIR, @eval TestJLL OpenLibm_jll.LIBPATH[])
        @test C_NULL == @eval TestJLL OpenLibm_jll.libnonexisting_handle

        @static if VERSION >= v"1.6.0-DEV"
            @test @eval TestJLL OpenLibm_jll.libnonexisting_path == "libreallynonexisting"
        else
            @test startswith(basename(@eval TestJLL OpenLibm_jll.libnonexisting_path), "libnonexisting")
        end

        # Issue #20
        if Sys.iswindows()
            @test Sys.BINDIR ∈ JLLWrappers.get_julia_libpaths()
        end

        # Package with a augment_platform!
        @static if VERSION >= v"1.6.0-DEV"
            Pkg.develop(PackageSpec(path=joinpath(@__DIR__, "LAMMPS_jll")))
            if VERSION < v"1.7"
                # On 1.6 we lazyily download the missing artifact, causing output to stderr
                @eval TestJLL using LAMMPS_jll
            else
                @test_nowarn @eval TestJLL using LAMMPS_jll
            end
            if @eval TestJLL LAMMPS_jll.is_available()
                @test @eval TestJLL LAMMPS_jll.abi == (Sys.iswindows() ? :MicrosoftMPI : :MPICH)
                @test isfile(@eval TestJLL LAMMPS_jll.liblammps_path)
                @test isfile(@eval TestJLL LAMMPS_jll.get_liblammps_path())
                @test isdir(@eval TestJLL LAMMPS_jll.artifact_dir)
                @test occursin(Sys.BINDIR, @eval TestJLL LAMMPS_jll.LIBPATH[])

                artifact_dir = @eval TestJLL LAMMPS_jll.artifact_dir

                if !Sys.iswindows()
                    @eval TestJLL LAMMPS_jll.set_abi(:MPItrampoline)
                    script = """
                    using Test
                    using LAMMPS_jll
                    @test LAMMPS_jll.abi == "MPItrampoline"
                    if !LAMMPS_jll.is_available()
                        @warn "LAMMPS_jll is not available, skipped test" LAMMPS_jll.host_platform
                        exit()
                    end
                    @test LAMMPS_jll.is_available()
                    @test isdir(LAMMPS_jll.artifact_dir)
                    @test LAMMPS_jll.artifact_dir !== $(repr(artifact_dir))
                    """
                    @test success(pipeline(`$(Base.julia_cmd()) --project=$dir -e $script`, stderr=stderr, stdout=stdout))
                end
            else
                platform = @eval TestJLL LAMMPS_jll.host_platform
                @warn "LAMMPS_jll is not available, skipped test" platform
            end
        end
    end
end
