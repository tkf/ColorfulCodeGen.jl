__precompile__(true)

module ColorfulCodeGen

using Compat

@static if VERSION < v"0.7-"
    using Base: gen_call_with_extracted_types
    using Base.Markdown: MD
    open_reader(cmd, proc_out) = open(cmd, "w", proc_out)
else
    using InteractiveUtils: gen_call_with_extracted_types_and_kwargs,
        code_lowered, code_typed, code_warntype, code_llvm, code_native
    using Markdown: MD
    function open_reader(cmd, proc_out)
        process = open(cmd, proc_out; write=true)
        return (process.in, process)
    end
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

function get_command(key, config::PygmentizeConfig = PYGMENTIZE)
    option = config.options[key]
    return `$(config.command) $option`
end

function with_highlighter(f, proc_out, highlighter)
    proc_in, process = open_reader(highlighter, proc_out)
    f(proc_in)
    close(proc_in)
    wait(process)
    return nothing
end

highlight(x) = highlight(stdout, x)
highlight(io::IO, x::Union{Expr, Core.CodeInfo}) =
    showpiped(io, x, get_command(Expr))
highlight(io::IO, x::MD) = showpiped(io, x, get_command(MD))

showpiped(thing, cmd::Cmd) = showpiped(stdout, thing, cmd)

function showpiped(io::IO, thing, cmd::Cmd)
    with_highlighter(io, cmd) do proc_in
        print(proc_in, sprint(show, MIME("text/plain"), thing))
    end
    nothing
end

const _with_io = (:code_warntype, :code_llvm, :code_native, :code_intel)
const _no_io = (:code_typed, :code_lowered)

for fname in (_with_io..., :show_sexpr)
    colored_name = Symbol("c$fname")
    @eval begin
        @doc $("""
            $(colored_name)([io,] args...; cmd::Cmd, kwargs...)

        Colored version of `$(fname)([io,] args...; kwargs...)`.
        """)
        function $(colored_name)(io::IO, args...;
                                 cmd = get_command($fname),
                                 kwargs...)
            with_highlighter(io, cmd) do proc_in
                $fname(proc_in, args...; kwargs...)
            end
        end
        $(colored_name)(args...; kwargs...) =
            $(colored_name)(stdout, args...; kwargs...)
    end
end

for fname in _no_io
    colored_name = Symbol("c$fname")
    @eval begin
        @doc $("""
            $(colored_name)([io,] args...; cmd::Cmd, kwargs...)

        Colored version of `$(fname)(args...; kwargs...)`.
        """)
        function $(colored_name)(io::IO, args...;
                                 cmd = get_command($fname),
                                 kwargs...)
            results = $fname(args...; kwargs...)
            result = length(results) == 1 ? results[1] : results
            # ^- from interactiveutil.jl
            showpiped(io, result, cmd)
        end
        $(colored_name)(args...; kwargs...) =
            $(colored_name)(stdout, args...; kwargs...)
    end
end

for fname in (_with_io..., _no_io...)
    colored_name = Symbol("c$fname")
    @eval begin
        macro ($colored_name)(ex0...)
            quoted = $(Expr(:quote, colored_name))
            if VERSION < v"0.7-"
                gen_call_with_extracted_types(quoted, ex0[1])
            else
                gen_call_with_extracted_types_and_kwargs(__module__, quoted, ex0)
            end
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
    if VERSION < v"0.7-"
        __module__ = current_module()
    end
    return :(highlight(dehygiene(macroexpand($__module__, $(QuoteNode(ex))))))
end

export @cmacroexpand

@static if VERSION >= v"0.7-"
    macro cmacroexpand1(ex)
        :(highlight(dehygiene(macroexpand($__module__, $(QuoteNode(ex));
                                          recursive = false))))
    end

    export @cmacroexpand1
end

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
