module GithubMarkdown

export rendergfm

const libpath = normpath(joinpath(@__DIR__, "..", "deps", "usr", "lib"))
const binary_path = normpath(joinpath(@__DIR__, "..", "deps", "usr", "bin", "cmark-gfm"))

@static if Sys.iswindows()
    const execenv = ("PATH" => string(libpath, ";", Sys.BINDIR))
elseif Sys.isapple()
    const execenv = ("DYLD_LIBRARY_PATH" => libpath)
else
    const execenv = ("LD_LIBRARY_PATH" => libpath)
end

# Load in `deps.jl`, complaining if it does not exist
const depsjl_path = joinpath(@__DIR__, "..", "deps", "deps.jl")
if !isfile(depsjl_path)
    error("GithubMarkdown not installed properly, run Pkg.build(\"GithubMarkdown\"), restart Julia and try again")
end
include(depsjl_path)

# Module initialization function
function __init__()
    # Always check your dependencies from `deps.jl`
    check_deps()
end


const EXTENSIONS = [
    "footnotes",
    "table",
    "strikethrough",
    "autolink",
    "tagfilter",
    "tasklist"
]

const FORMATS = [
    "html",
    "xml",
    "man",
    "commonmark",
    "plaintext",
    "latex"
]

"""
    rendergfm(output::IO, input::IO; documenter = false, format="html", removehtml = false, extensions=EXTENSIONS)
    rendergfm(output::IO, input::AbstractString; documenter = false, format="html", removehtml = false, extensions=EXTENSIONS)
    rendergfm(output::AbstractString, input::AbstractString; documenter = false, format="html", removehtml = false, extensions=EXTENSIONS)

Render the markdown document `input` to `output`, following the cmark-gfm spec.

- `documenter`: Wraps the output in a Documenter `@raw`-block of the specified format.
- `format`: Can be one of `html`, `xml`, `man`, `commonmark`, `plaintext`, `latex`.
- `removehtml`: Removes all literal HTML input and potentially dangerous links if `true`. `false`
  by default. The `tagfilter` extension (enabled by default) will remove most malicious raw HTML.
  It's recommended to sanitize the resulting HTML when `removehtml == false`.
- `extensions`: An array of extensions to use. Valid extensions are `footnotes`, `table`,
  `strikethrough`, `autolink`, `tagfilter`, `tasklist`. All of those are enabled by default.

Spec: https://github.github.com/gfm/
"""
function rendergfm end

function rendergfm(output::AbstractString, input::AbstractString; kwargs...)
    io = IOBuffer()
    rendergfm(io, input; kwargs...)

    open(output, "w") do input
        write(input, seekstart(io))
    end

    return output
end

function rendergfm(output::IO, input::AbstractString; kwargs...)
    isfile(input) || throw(ErrorException("File not found."))

    open(input) do input
        rendergfm(output, input; kwargs...)
    end

    return nothing
end

function rendergfm(output::IO, input::IO; documenter = false, format="html", removehtml = false, extensions=EXTENSIONS)
    if !(format in FORMATS)
        throw(ArgumentError("""
            Invalid format `$(format)`.
            Only $(join(map(s -> string('`', s, '`'), FORMATS), ", ")) are supported.
        """))
    end

    for ext in extensions
        if !(ext in EXTENSIONS)
            throw(ArgumentError("""
                Invalid extension `$(ext)`.
                Only $(join(map(s -> string('`', s, '`'), EXTENSIONS), ", ")) are supported.
            """))
        end
    end

    flags = String["-t", format, "--width", "100"]

    !removehtml && push!(flags, "--unsafe")

    for ext in extensions
        push!(flags, "-e")
        push!(flags, ext)
    end

    withenv(execenv) do
        documenter && println(output, "````````````@raw ", format)
        p = pipeline(input, `$(binary_path) $(flags)`)
        print(output, read(p, String))
        documenter && println(output, "\n````````````")
    end

    return nothing
end

end # module
