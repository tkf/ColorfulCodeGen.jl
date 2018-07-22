using ColorfulCodeGen
using Compat: @warn
@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

macro test_nothrow(ex)
    quote
        @test begin
            $(esc(ex))
            true
        end
    end
end

@testset "Smoke tests" begin
    @test_nothrow @ccode_warntype 1.0im + 1.0im
    @test_nothrow @ccode_llvm     1.0im + 1.0im
    @test_nothrow @ccode_native   1.0im + 1.0im
    @test_nothrow @ccode_typed    1.0im + 1.0im
    @test_nothrow @ccode_lowered  1.0im + 1.0im
    @test_nothrow @macroexpand @warn "hello"
    @test_nothrow ColorfulCodeGen.highlight(@macroexpand @warn "hello")
end
