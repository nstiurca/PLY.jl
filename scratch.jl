
import FileIO
using PLY

ex0_fname = joinpath(Pkg.dir("PLY"), "data", "ex0.ply")
ex1_fname = joinpath(Pkg.dir("PLY"), "data", "ex1.ply")

ex0 = load(ex0_fname)
ex1 = load(ex1_fname)

quote
syms = [:a, :b, :c]
typs = [Int, Float32, Char]
e = :(type Foo end)
e.args[3].args = [:($sym::$typ) for (sym,typ) in zip(syms,typs)]
e
end

f = :(type bar
  $(sym::typ for (sym,typ) in zip(syms,typs))
end)

:(type bar; $([:($sym::$typ) for (sym,typ) in zip(syms,typs)]...);end)

members = [:($sym::$typ) for (sym,typ) in zip(syms,typs)]
:(type bar; $(members...); end)

immutable vertex
  x::Float32
  y::Float32
  z::Float32
end

immutable face
  vertex_index::Vector{Int32}
end

## vertex parsing
E = vertex
E = face

exprs = [ :(vs = split(readline(f))),
          :(it = start(vs))]
for (prop_name, prop_type) in zip(fieldnames(E), E.types)
  if prop_type <: Number
    push!(exprs, :((_tmp, it) = next(vs, it)))
    push!(exprs, :($prop_name = parse($prop_type, _tmp)))
  elseif prop_type <: Vector
    prop_eltype = eltype(prop_type)
    push!(exprs, :((_tmp, it) = next(vs, it)))
    push!(exprs, :($prop_name = Array($prop_eltype, parse(Int, _tmp))))
    push!(exprs, :(for _i = 1 : length($prop_name)
                    (_tmp, it) = next(vs, it)
                    $prop_name[_i] = parse($prop_eltype, _tmp)
                  end))
  else
    error("Unsupported property $prop_name::$prop_type")
  end
end
push!(exprs, :(done(vs, it) || error("Unexpected toxens left over in \$vs starting at \$it.")))

ctor_args = [:($prop_name) for prop_name in fieldnames(E)]
ctor_args = fieldnames(E)
push!(exprs, :($E($(fieldnames(E)...))))
ret = :($(exprs...))
ret = quote $(exprs...) end
