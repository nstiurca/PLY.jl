import PLY

ex0_fname = joinpath(Pkg.dir("PLY"), "data", "ex0.ply")
ex1_fname = joinpath(Pkg.dir("PLY"), "data", "ex1.ply")

f0 = open(ex0_fname, "r")
hdr = PLY.header(f0)
close(f0)

hdr = open(ex0_fname, "r") do f PLY.header(f) end

types = instantiate_types(hdr)


i=1

i += 1


vs = split("42 4 2 6 7 3 24")
it = start(vs)
meaning, it = next(vs, it)
count, it = next(vs, it)

map(int32, vs[it:it+uint8(count)-1])

it += uint8(count)  # parse later
life, it = next(vs, it)
@assert done(vs, it)

vals = Array(Int32, )
vals = [int32(x) for x in take(vs, uint8(count))]

function parse_property(vs, it, p::PLY.AProperty)
end

function parse_property(vs, it, p::PLY.Property)
  val, it = next(vs, it)
  PLY.TYPE_READERS[p.typ](val), it
end

function parse_property(vs, it, p::PLY.ListProperty)
  count_str, it = next(vs, it)
  count = PLY.TYPE_READERS[p.count_type](count_str)
  map(PLY.TYPE_READERS[p.typ], vs[it:it+count-1]), it+count
end

function parse_property_impl_string_ascii(p::PLY.AProperty)
end

function parse_property_impl_string_ascii(p::PLY.Property)
  "$(string(p.name)), it = next(vs, it)"
end

function parse_property_impl_string_ascii(p::PLY.ListProperty)
  "$(string)"
end


function element_impl_string_ascii(e::PLY.Element; tab="  ")
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
    push!(lines, "$(tab)$(string(p.name)), it = parse_property(vs, it, PLY.$(repr(p)))")
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

####
immutable vertex
  x::Float32
  y::Float32
  z::Float32
end

function read_vertex_ascii(f::IO)
  vs = split(readline(f))
  it = start(vs)
  x, it = parse_property(vs, it, PLY.Property(:x,Float32))
  y, it = parse_property(vs, it, PLY.Property(:y,Float32))
  z, it = parse_property(vs, it, PLY.Property(:z,Float32))

  done(vs, it) || error("Unexpected toneks left over in $vs starting at $it.")

  vertex(x, y, z)
end

immutable face2
  vertex_index::Vector{Int32}
end

function read_face_ascii(f::IO)
  vs = split(readline(f))
  it = start(vs)
  vertex_index, it = parse_property(vs, it, PLY.ListProperty(:vertex_index,Int32,Uint8))

  done(vs, it) || error("Unexpected toneks left over in $vs starting at $it.")

  face2(vertex_index)
end

