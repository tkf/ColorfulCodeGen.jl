using ColorfulCodeGen
using ColorfulCodeGen: highlight
using Compat: @warn, devnull
using Compat.Test

@static if VERSION >= v"0.7-"
    import Markdown
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
    @test_nothrow @cmacroexpand @warn "hello"
    @static if VERSION >= v"0.7.0-"
        @test_nothrow @cmacroexpand1 @warn "hello"
    end
    @test_nothrow highlight(devnull, :(1.0im + 1.0im))
    # Old pygmentize (available in Travis) does not have md lexer?:
    @test_skip highlight(devnull, Markdown.parse(IOBuffer("# Title")))
end
