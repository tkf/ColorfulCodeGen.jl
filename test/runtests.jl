using ColorfulCodeGen
using Compat: @warn
using Compat.Test

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
    @test_nothrow @cmacroexpand @warn "hello"
    @static if VERSION >= v"0.7.0-"
        @test_nothrow @cmacroexpand1 @warn "hello"
    end
    @test_nothrow ColorfulCodeGen.highlight(@macroexpand @warn "hello")
end
