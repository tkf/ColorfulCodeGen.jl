module ColorfulCodeGen

using InteractiveUtils: gen_call_with_extracted_types_and_kwargs,
    code_lowered, code_typed, code_warntype, code_llvm, code_native
using Markdown: MD
function open_reader(cmd, proc_out)
    process = open(cmd, proc_out; write=true)
    return (process.in, process)
end

using Base.Meta: show_sexpr

mutable struct PygmentizeConfig
    command::Cmd
    options::Dict{Any, Cmd}
end

code_intel(args...) = code_native(args...; syntax=:intel)

const PYGMENTIZE = PygmentizeConfig(
    `pygmentize -f terminal256`,
    Dict(
        code_lowered  => `-l julia`,
        code_typed    => `-l julia`,
        code_warntype => `-l julia`,
        code_llvm     => `-l llvm`,
        code_native   => `-l asm`,
        code_intel    => `-l nasm`,
        show_sexpr    => `-l scheme`,
        Expr          => `-l julia`,
        MD            => `-l md`,
    ),
)

struct ColoredCode
    text::String
    optionkey
end

function Base.show(io::IO, ::MIME"text/plain", cc::ColoredCode)
    if get(io, :compact, false) || get(io, :typeinfo, Any) === ColoredCode
        print(io, "ColoredCode(")
        text = repr(cc.text)
        if get(io, :limit, true) && length(text) > 20
            print(io, first(text, 20))
            printstyled(io, '…'; color=:light_black)
            print(io, '"')
        else
            print(io, text)
        end
        print(io, ", ", cc.optionkey, ")")
        return
    end
    highlighter = get_command(cc.optionkey)
    proc_in, process = open_reader(highlighter, io)
    try
        print(proc_in, cc.text)
    finally
        close(proc_in)
        wait(process)
    end
    return
end

function get_command(key, config::PygmentizeConfig = PYGMENTIZE)
    option = config.options[key]
    return `$(config.command) $option`
end

mimefor(_) = MIME"text/plain"()
mimefor(::MD) = MIME"text/markdown"()

function highlight(x)
    text = sprint(show, mimefor(x), x)
    return ColoredCode(text, typeof(x))
end

const _with_io = (:code_warntype, :code_llvm, :code_native, :code_intel)
const _no_io = (:code_typed, :code_lowered)

for fname in (_with_io..., :show_sexpr)
    colored_name = Symbol("c$fname")
    @eval begin
        @doc $("""
            $(colored_name)([io,] args...; kwargs...)

        Colored version of `$(fname)([io,] args...; kwargs...)`.
        """)
        function $(colored_name)(args...; kwargs...)
            text = sprint() do io
                $fname(io, args...; kwargs...)
            end
            return ColoredCode(text, $fname)
        end
    end
end

for fname in _no_io
    colored_name = Symbol("c$fname")
    @eval begin
        @doc $("""
            $(colored_name)([io,] args...; kwargs...)

        Colored version of `$(fname)(args...; kwargs...)`.
        """)
        function $(colored_name)(args...; kwargs...)
            results = $fname(args...; kwargs...)
            result = length(results) == 1 ? results[1] : results
            # ^- from interactiveutil.jl
            text = sprint(show, MIME("text/plain"), result)
            return ColoredCode(text, $fname)
        end
    end
end

for fname in (_with_io..., _no_io...)
    colored_name = Symbol("c$fname")
    @eval begin
        $(colored_name)(io::IO, args...; kwargs...) =
            show(io, MIME"text/plain"(), $(colored_name)(args...; kwargs...))
        macro ($colored_name)(ex0...)
            quoted = $(Expr(:quote, colored_name))
            gen_call_with_extracted_types_and_kwargs(__module__, quoted, ex0)
        end

        export $colored_name
        export $(Symbol("@$colored_name"))
    end
end

dehygiene(expr::Expr) = Expr(expr.head, dehygiene.(expr.args)...)
dehygiene(x::Any) = x  # LineNumberNode etc.

function dehygiene(sym::Symbol)
    str = string(sym)
    if startswith(str, "#")
        return Symbol(replace(str, "#" => "😷"))
    else
        return sym
    end
end

"""
    @cmacroexpand ex

Print syntax highlighted expression of what `@macroexpand ex` returns.
"""
macro cmacroexpand(ex)
    return :(highlight(dehygiene(macroexpand($__module__, $(QuoteNode(ex))))))
end

export @cmacroexpand

macro cmacroexpand1(ex)
    :(highlight(dehygiene(macroexpand($__module__, $(QuoteNode(ex));
                                      recursive = false))))
end

export @cmacroexpand1

export @cshow_sexpr

"""
    @cshow_sexpr expression

Print S-expression of Julia `expression`; it's a colored version of
`Meta.show_sexpr(:(expression))`.
"""
macro cshow_sexpr(ex)
    :($cshow_sexpr($(QuoteNode(ex))))
end

export @clowered

"""
    @clowered expression

Print lowered form of `expression`; it's a colored version of
`Meta.lower(Main, :(expression))`.
"""
macro clowered(ex)
    quote
        let ex = Meta.lower($__module__, $(QuoteNode(ex)))
            if ex isa $Expr && length(ex.args) == 1 &&
                    ex.args[1] isa $(Core.CodeInfo)
                ex = ex.args[1]
            end
            $highlight(ex)
        end
    end
end

end # module
