# convert `md"""blah"""` to markdown cells in jupyter notebook

using JSON
import DataStructures

j = JSON.parsefile("pres.ipynb", dicttype=DataStructures.OrderedDict)

open("pres-out.ipynb", "w") do io
    let indentation = 1
        JSON.print(io, j, indentation)
    end
end
