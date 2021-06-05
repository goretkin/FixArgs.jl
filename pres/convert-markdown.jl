# convert `md"""blah"""` to markdown cells in jupyter notebook

using JSON
j = JSON.parsefile("pres.ipynb")

open("pres-out.ipynb", "w") do io
    write(io, JSON.json(j))
end
