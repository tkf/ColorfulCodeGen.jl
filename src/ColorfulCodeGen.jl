__precompile__(true)

module ColorfulCodeGen

using Compat

@static if VERSION < v"0.7-"
    using Base: gen_call_with_extracted_types
    using Base.Markdown: MD
    open_reader(cmd, proc_out) = open(cmd, "w", proc_out)
else
    using InteractiveUtils: gen_call_with_extracted_types,
        code_lowered, code_typed, code_warntype, code_llvm, code_llvm_raw,
        code_native
    using Markdown: MD
    open_reader(cmd, proc_out) = open(cmd, proc_out; write=true)
end

const _PYGMENTIZE = `pygmentize -f terminal256`
const HIGHLIGHTERS = let
    pygmentize = _PYGMENTIZE
    Dict(
        :code_lowered  => `$pygmentize -l julia`,
        :code_typed    => `$pygmentize -l julia`,
        :code_warntype => `$pygmentize -l julia`,
        :code_llvm     => `$pygmentize -l llvm`,
        :code_llvm_raw => `$pygmentize -l llvm`,
        :code_native   => `$pygmentize -l cpp-objdump`,
    )
end

function with_highlighter(f, proc_out, highlighter)
    proc_in, process = open_reader(highlighter, proc_out)
    f(proc_in)
    close(proc_in)
    wait(process)
    return nothing
end

highlight(x) = highlight(stdout, x)
highlight(io::IO, x::Expr) = showpiped(io, x, `$_PYGMENTIZE -l julia`)
highlight(io::IO, x::MD) = showpiped(io, x, `$_PYGMENTIZE -l md`)

showpiped(thing, cmd::Cmd) = showpiped(stdout, thing, cmd)

function showpiped(io::IO, thing, cmd::Cmd)
    with_highlighter(io, cmd) do proc_in
        print(proc_in, sprint(show, MIME("text/plain"), thing))
    end
    nothing
end

const _with_io = (:code_warntype, :code_llvm, :code_llvm_raw, :code_native)
const _no_io = (:code_typed, :code_lowered)

for fname in _with_io
    colored_name = Symbol("c$fname")
    @eval begin
        @doc $("""
            $(colored_name)([io,] args...)

        Colored version of `$(fname)([io,] args...)`.
        """)
        function $(colored_name)(io::IO, args...)
            with_highlighter(proc_in -> $fname(proc_in, args...),
                             io, HIGHLIGHTERS[$(QuoteNode(fname))])
        end
        $(colored_name)(args...) = $(colored_name)(stdout, args...)
    end
end

for fname in _no_io
    colored_name = Symbol("c$fname")
    @eval begin
        @doc $("""
            $(colored_name)([io,] args...)

        Colored version of `$(fname)(args...)`.
        """)
        function $(colored_name)(io::IO, args...)
            highlighter = HIGHLIGHTERS[$(QuoteNode(fname))]
            results = $fname(args...)
            result = length(results) == 1 ? results[1] : results
            # ^- from interactiveutil.jl
            showpiped(io, result, highlighter)
        end
        $(colored_name)(args...) = $(colored_name)(stdout, args...)
    end
end

for fname in (_with_io..., _no_io...)
    colored_name = Symbol("c$fname")
    @eval begin
        macro ($colored_name)(ex0)
            quoted = $(Expr(:quote, colored_name))
            if VERSION < v"0.7-"
                gen_call_with_extracted_types(quoted, ex0)
            else
                gen_call_with_extracted_types(__module__, quoted, ex0)
            end
        end

        export $colored_name
        export $(Symbol("@$colored_name"))
    end
end

end # module
