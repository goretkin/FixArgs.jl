# convert `md"""blah"""` to markdown cells in jupyter notebook

using JSON
import DataStructures

j = JSON.parsefile("pres.ipynb", dicttype=DataStructures.OrderedDict)

function cell_convert(cell)
    get(cell, "cell_type", nothing) == "code" || return cell
    source_lines = cell["source"]
    source = join(source_lines, "\n")
    parsed_all = try
        Meta.parseall(source)
    catch e
        if e isa Base.Meta.ParseError
            println("warning, skipping unparsable: ")
            println(source)
            println(e)
            return cell
        end
        rethrow(e)
    end
    parsed_all.head === :toplevel || error()
    i_exprs = findall(==(Expr), typeof.(parsed_all.args))
    length(i_exprs) == 1 || return cell
    i_expr = only(i_exprs)
    parsed = parsed_all.args[i_expr]
    parsed.head == :macrocall || return cell
    parsed.args[1] == Symbol("@md_str") || return cell
    i_string = only(findall(==(String), typeof.(parsed.args)))
    md = parsed.args[i_string]
    md_out = strip(md)
    cell_output = deepcopy(cell)
    delete!(cell_output, "execution_count")
    delete!(cell_output, "outputs")
    cell_output["cell_type"] = "markdown"
    cell_output["source"] = [md_out]
    return cell_output
end

j["cells"] = map(cell_convert, j["cells"])

open("pres-out.ipynb", "w") do io
    let indentation = 1
        JSON.print(io, j, indentation)
    end
end
