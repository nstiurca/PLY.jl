#using PLY
# println("file: ascii.jl")

function parse_property(vs, it, p::AProperty)
end

function parse_property(vs, it, p::Property)
  val, it = next(vs, it)
  TYPE_READERS[p.typ](val), it
end

function parse_property(vs, it, p::ListProperty)
#   println(it)
  count_str, it = next(vs, it)
#   println(it)
  count = TYPE_READERS[p.count_type](count_str)
#   println(it+count)
  map(TYPE_READERS[p.typ], vs[it:it+count-1]), it+count
end

function parse_property_impl_string_ascii(p::AProperty)
end

function parse_property_impl_string_ascii(p::Property)
  "$(string(p.name)), it = next(vs, it)"
end

function parse_property_impl_string_ascii(p::ListProperty)
  "$(string(p.name))_count, it = next(vs, it)"
end


function element_impl_string_ascii(e::Element; tab="  ")
  # define the type
  lines = ["immutable $(string(e.name))"]
  for p = e.properties
    push!(lines, tab * string(p)) #"$(tab)$(string(p.name))::$(string(p.typ))")
  end
  push!(lines, "end")
  defn = join(lines, "\n")

  # define reading each property
  lines = ["function read_$(string(e.name))_ascii(f::IO)",
           "$(tab)vs = split(readline(f))",
           "$(tab)it = start(vs)"]
  for p=e.properties
    #push!(lines, "$(tab)$(string(p.name)), it = parse_property(vs, it, p)")
    push!(lines, "$(tab)$(string(p.name)), it = Main.parse_property(vs, it, $(repr(p)))")
    #push!(lines, tab * parse_property_impl_string_ascii(p))
  end
  # check that we parsed exactly the right number of things
  push!(lines, "\n$(tab)done(vs, it) || error(\"Unexpected toneks left over in \$vs starting at \$it.\")\n")
  args = join(map(p->string(p.name), e.properties), ", ")
  push!(lines, "$(tab)$(string(e.name))($args)")
  push!(lines, "end")
  ascii_reader = join(lines, "\n")

  defn, ascii_reader
end

element_impl_expr(e::Element, ::Type{FORMAT_ASCII}) = element_impl_expr_ascii(e)
function element_impl_expr_ascii(e::Element)
  ascii_reader = :(function Base.read(f::IO, ::Type{$(e.name)})
                     vs = split(readline(f))
                     it = start(vs)
                   end)
  for (i, p) in enumerate(e.properties)
    push!(ascii_reader.args[2].args, :(($(p.name), it) = Main.parse_property(vs, it, $p)))
  end
  push!(ascii_reader.args[2].args, :(done(vs,it) || error("Unexpected tokens left over in $(vs) starting at $(it).")))
  construct = :($(e.name)())
  for p=e.properties
    push!(construct.args, p.name)
  end
  push!(ascii_reader.args[2].args, construct)

  ascii_reader
end

function load(f::IO, hdr::Header)
  types = instantiate_types(hdr)
  elem_arrays = Array[]
  for (elem, typ) in zip(hdr.elements, types)
    eval(element_impl_expr_ascii(elem))
    elem_array = Array(typ, elem.count)

    for i = 1:elem.count
      elem_array[i] = read(f, typ)
    end

    push!(elem_arrays, elem_array)
  end
#   Dict([hdr.elements[i].name => elem_arrays[i] for i in 1:N])
#   Dict([e.name for e in hdr.elements], elem_arrays)

  hdr_expr = expr(hdr)
  eval(hdr_expr)
  hdr_symbol = hdr_expr.args[2]
  construct = eval(hdr_symbol)
  construct(elem_arrays...)
end

println("loaded ascii.jl")
