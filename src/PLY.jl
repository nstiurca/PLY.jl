module PLY

# package code goes here

const MAGIC = "ply\n"
# const FORMAT_ASCII                   = 1
# const FORMAT_BINARY_LITTLE_ENDIAN    = 2
# const FORMAT_BINARY_BIG_ENDIAN       = 3
abstract FORMAT
type FORMAT_ASCII <: FORMAT end
type FORMAT_BINARY_LITTLE_ENDIAN end
type FORMAT_BINARY_BIG_ENDIAN end
FORMATS = Union{Type{FORMAT_ASCII}, Type{FORMAT_BINARY_LITTLE_ENDIAN}, Type{FORMAT_BINARY_BIG_ENDIAN}}

# function format_string end
format_string(::Type{FORMAT_ASCII}) = "ascii"
format_string(::Type{FORMAT_BINARY_LITTLE_ENDIAN}) = "binary_little_endian"
format_string(::Type{FORMAT_BINARY_BIG_ENDIAN}) = "binary_big_endian"

# const FORMAT_STRINGS = [
#   "ascii",
#   "binary_little_endian",
#   "binary_big_endian"]
const FORMAT_TYPE = Dict(
  format_string(FORMAT_ASCII)                 => FORMAT_ASCII,
  format_string(FORMAT_BINARY_LITTLE_ENDIAN)  => FORMAT_BINARY_LITTLE_ENDIAN,
  format_string(FORMAT_BINARY_BIG_ENDIAN)     => FORMAT_BINARY_BIG_ENDIAN)

#   Dict(zip(FORMAT_STRINGS, 1:3))

# TODO: Type comes out as ASCIIString -> Any, should be ASCIIString -> Type
const PROPERTY_TYPES = Dict(
  "char"    => Int8,
  "uchar"   => UInt8,
  "short"   => Int16,
  "ushort"  => UInt16,
  "int"     => Int32,
  "uint"    => UInt32,
  "float"   => Float32,
  "double"  => Float64)

# TODO: Type comes out as Any -> ASCIIString, should be Type -> ASCIIString
const TYPE_STRINGS = Dict(
  Int8    => "char",
  UInt8   => "uchar",
  Int16   => "short",
  UInt16  => "ushort",
  Int32   => "int",
  UInt32  => "uint",
  Float32 => "float",
  Float64 => "double")
const TYPE_READERS = Dict(
  Int8    => int8,
  UInt8   => uint8,
  Int16   => int16,
  UInt16  => uint16,
  Int32   => int32,
  UInt32  => uint32,
  Float32 => float32,
  Float64 => float64)
# TODO: Type comes out as Any -> ASCIIString, should be Type -> ASCIIString
const TYPE_STRINGS_COMPACT = Dict(
  Int8    => "i8",
  UInt8   => "u8",
  Int16   => "i16",
  UInt16  => "u16",
  Int32   => "i32",
  UInt32  => "u32",
  Float32 => "f32",
  Float64 => "f64")

abstract AProperty

type Property <:AProperty
  name::Symbol
  typ::DataType        # FIXME: SHould it be Type or DataType?
end
Property(name, typ) = Property(symbol(name), PROPERTY_TYPES[typ])
# Base.showcompact(io::IO, p::Property) = print(io, "property $(p.name) $(TYPE_STRINGS[p.typ])")

type ListProperty <: AProperty
  name::Symbol
  typ::DataType        # FIXME: SHould it be Type or DataType?
  count_type::DataType        # FIXME: SHould it be Type or DataType?
end
ListProperty(name, typ, count_type) = ListProperty(symbol(name), PROPERTY_TYPES[typ], PROPERTY_TYPES[count_type]) # Base.showcompact(io::IO, p::ListProperty) = print(io, "property list $(TYPE_STRINGS[p.count_type]) $(p.name) $(TYPE_STRINGS[p.typ])")
type Element
  name::Symbol
  count::Int
  properties::Vector{AProperty}
end
Element(name, count) = Element(name, parse(Int, count), Array(AProperty, 0))

type Header
  format::FORMATS
  version::ASCIIString
  elements::Vector{Element}
end
Header(format, version) = Header(format, version, Array(Element,0))
function Header(format_line::ASCIIString)
  words = split(format_line)
  if "format" != words[1]
    throw(ParseError("Expected format line to begin with \"format\". The line is instead " * format_line))
  end
  Header(FORMAT_TYPE[words[2]], words[3])
end

export header
function header(f)
  # check magic number
  f_magic = readbytes(f, 4)
  if f_magic[4] == '\r'
    # looks like Windows \r\n bull, so read another byte
    f_magic[4] = read(f, UInt8)
  end
  if f_magic != MAGIC.data
    throw(ParseError("Bad magic number: " * string(f_magic)))
  end

  hdr = Header(readline(f))
  lines_read = 2    # MAGIC and format

  for line in eachline(f)
    words = split(line)
    lines_read += 1

    # handle each kind of line
    if words[1] == "property"
      if words[2] == "list"
        push!(hdr.elements[end].properties, ListProperty(words[5], words[4], words[3]))
      else
        push!(hdr.elements[end].properties, Property(words[3], words[2]))
      end

    elseif words[1] == "element"
      push!(hdr.elements, Element(words[2], words[3]))

  elseif words[1] == "comment"
      # TODO: save coments to header
      continue

    elseif words[1] == "end_header"
      break

    else
      throw(ParseError("Unknown header line on line $lines_read"))
    end
  end # eachline(f)

  return hdr
end # function header

Base.string(p::Property) = "$(p.name)::$(string(p.typ))"
Base.string(p::ListProperty) = "$(p.name)::Vector{$(string(p.typ))}"

function julia_type(e::Element)
  str = "immutable Element_$(e.name)\n"
  for p = e.properties
    str *= "\t$(string(p))\n"
  end
  str *= "end"
end

export expr
expr(p::Property) = :($(p.name) :: $(p.typ))
expr(p::ListProperty) = :($(p.name) :: Vector{$(p.typ)})
function expr(h::Header)
  s = gensym("PLY_file")
  #s = :PLY_file

  typ = :(type $s end)
  ctor = :($s() = $s())
  reader = :(function Base.read(f::IO, ::Type{$s})
            ret = $s()
          end)

  for e in h.elements
    push!(typ.args[3].args, :($(e.name)::Vector{$(e.name)}))

    e_count = symbol(string(e.name)*"_count")
    push!(ctor.args[1].args, :($e_count::Integer))
    push!(ctor.args[2].args, :(Array($(e.name), $e_count)))


    push!(reader.args[2].args[2].args[2].args, e.count)
    push!(reader.args[2].args, :(for i=1:$(e.count)
                                (ret.$(e.name))[i] = read(f, $(e.name))
                              end))
  end

  push!(reader.args[2].args, :(ret))

  [typ, ctor, reader]
end

expr(e::Element) = begin
  defn = :(immutable $(e.name) end)
  defn.args[3].args = map(expr, e.properties)
  defn
end

export instantiate_types
function instantiate_types(h::Header)
  types = map(expr, h.elements)   # build expressions for each type
  map(eval, types)                    # instantiate the types
  map(t -> eval(t.args[2]), types)    # return a DataType for each type
end

get_type(e::Element) = eval(e.name)

# function read_ascii(AProperty)

# function read_ascii(f::IO, e::Element)
#   typ = get_type(e)
#   data = Array(typ, e.count)
#   for i=1:e.count
#     val_strs = split(readline(f))
#     it = start(val_strl)


#module ascii
#include(joinpath(Pkg.dir("PLY"), "src", "ascii.jl"))
include("ascii.jl")
#end

function load(f0::IO)
  hdr = header(f0)

  type_exprs = map(expr, hdr.elements)
  read_exprs = map(e->element_impl_expr(e, hdr.format), hdr.elements)
  hdr_exprs = expr(hdr)

  module_expr = :(module $(gensym()) end)
  module_name = module_expr.args[2]
  module_expr.args[3].args = union(module_expr.args[3].args, type_exprs, read_exprs, hdr_exprs)
  println(module_expr)
  eval(module_expr)
  M = eval(module_name)
  println(M)
  println(hdr_exprs[1].args[2])
  ply0 = read(f0, eval(M, :($(hdr_exprs[1].args[2]))))
end

end # module
