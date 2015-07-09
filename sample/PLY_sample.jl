import PLY

ex0_fname = joinpath(Pkg.dir("PLY"), "data", "ex0.ply")
ex1_fname = joinpath(Pkg.dir("PLY"), "data", "ex1.ply")

f0 = open(ex0_fname, "r")

hdr = header(f0)

type_exprs = map(expr, hdr.elements)
read_exprs = map(e->element_impl_expr(e, hdr.format), hdr.elements)
hdr_exprs = expr(hdr)

module_expr = :(module BAR end)
s = module_expr.args[2] = gensym()
module_expr.args[3].args = union(module_expr.args[3].args, type_exprs, read_exprs, hdr_exprs)
eval(module_expr)
ply0 = read(f0, eval(:($s.$(hdr_exprs[1].args[2]))))

close(f0)

ex0 = open(ex0_fname, "r") do f load(f) end
ex1 = open(ex1_fname, "r") do f load(f) end

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


function Base.read(f::IO, ::Type{PLY_file})
  counts = map(e->e.count, hdr.elements)
  ret = PLY_file(counts...)

  for i=1:counts[1]
    ret.vertex[i] = read(f, vertex)
  end

  for i=1:counts[2]
    ret.face[i] = read(f, face)
  end

  ret
end
