module ColorfulCodeGen

using Compat

@static if VERSION < v"0.7-"
    using Base: gen_call_with_extracted_types
    open_reader(cmd, proc_out) = open(cmd, "w", proc_out)
else
    using InteractiveUtils: gen_call_with_extracted_types
end

const HIGHLIGHTERS = Dict(
    :code_warntype => `pygmentize -f terminal256 -l julia`,
    :code_llvm     => `pygmentize -f terminal256 -l llvm`,
    :code_llvm_raw => `pygmentize -f terminal256 -l llvm`,
    :code_native   => `pygmentize -f terminal256 -l cpp-objdump`
)

function call_with_highlighter(f, proc_out, highlighter)
    proc_in, process = open_reader(highlighter, proc_out)
    f(proc_in)
    close(proc_in)
    wait(process)
    return nothing
end

for fname in [:code_warntype, :code_llvm, :code_llvm_raw, :code_native]
    colored_name = Symbol("c$fname")
    @eval begin
        @doc $("""
            $(colored_name)([io,] args...)

        Colored version of `$(fname)([io,] args...)`.
        """) ->
        function $(colored_name)(io::IO, args...)
            call_with_highlighter(proc_in -> $fname(proc_in, args...),
                                  io, HIGHLIGHTERS[$(QuoteNode(fname))])
        end
        $(colored_name)(args...) = $(colored_name)(stdout, args...)

        macro ($colored_name)(ex0)
            gen_call_with_extracted_types($(Expr(:quote, colored_name)), ex0)
        end

        export $colored_name
        export $(Symbol("@$colored_name"))
    end
end

end # module
