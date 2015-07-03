module PLY

# package code goes here

const MAGIC = "ply\n"
const FORMAT_ASCII                   = 1
const FORMAT_BINARY_LITTLE_ENDIAN    = 2
const FORMAT_BINARY_BIG_ENDIAN       = 3
const FORMAT_STRINGS = ["ascii", "binary_little_endian", "binary_big_endian"]
const FORMAT_NUMERALS = [
  FORMAT_STRINGS[FORMAT_ASCII]                 => FORMAT_ASCII,
  FORMAT_STRINGS[FORMAT_BINARY_LITTLE_ENDIAN]  => FORMAT_BINARY_LITTLE_ENDIAN,
  FORMAT_STRINGS[FORMAT_BINARY_BIG_ENDIAN]     => FORMAT_BINARY_BIG_ENDIAN]

#   Dict(zip(FORMAT_STRINGS, 1:3))

# TODO: Type comes out as ASCIIString -> Any, should be ASCIIString -> Type
const PROPERTY_TYPES = [
  "char"    => Int8,
  "uchar"   => Uint8,
  "short"   => Int16,
  "ushort"  => Uint16,
  "int"     => Int32,
  "uint"    => Uint32,
  "float"   => Float32,
  "double"  => Float64]

# TODO: Type comes out as Any -> ASCIIString, should be Type -> ASCIIString
const TYPE_STRINGS = [
  Int8    => "char",
  Uint8   => "uchar",
  Int16   => "short",
  Uint16  => "ushort",
  Int32   => "int",
  Uint32  => "uint",
  Float32 => "float",
  Float64 => "double"]
const TYPE_READERS = [
  Int8    => int8,
  Uint8   => uint8,
  Int16   => int16,
  Uint16  => uint16,
  Int32   => int32,
  Uint32  => uint32,
  Float32 => float32,
  Float64 => float64]
# TODO: Type comes out as Any -> ASCIIString, should be Type -> ASCIIString
const TYPE_STRINGS_COMPACT = [
  Int8    => "i8",
  Uint8   => "u8",
  Int16   => "i16",
  Uint16  => "u16",
  Int32   => "i32",
  Uint32  => "u32",
  Float32 => "f32",
  Float64 => "f64"]

abstract AProperty

type Property <:AProperty
  name::Symbol
  typ::DataType        # FIXME: SHould it be Type or DataType?
end
Property(name, typ::String) = Property(symbol(name), PROPERTY_TYPES[typ])
# Base.showcompact(io::IO, p::Property) = print(io, "property $(p.name) $(TYPE_STRINGS[p.typ])")

type ListProperty <: AProperty
  name::Symbol
  typ::DataType        # FIXME: SHould it be Type or DataType?
  count_type::DataType        # FIXME: SHould it be Type or DataType?
end
ListProperty(name, typ::String, count_type::String) = ListProperty(symbol(name), PROPERTY_TYPES[typ], PROPERTY_TYPES[count_type])
# Base.showcompact(io::IO, p::ListProperty) = print(io, "property list $(TYPE_STRINGS[p.count_type]) $(p.name) $(TYPE_STRINGS[p.typ])")

type Element
  name::Symbol
  count::Int
  properties::Vector{AProperty}
end
Element(name, count) = Element(name, int(count), Array(AProperty, 0))

type Header
  format::ASCIIString
  version::ASCIIString
  elements::Vector{Element}
end
Header(format, version) = Header(format, version, Array(Element,0))
function Header(format_line::ASCIIString)
  words = split(format_line)
  if "format" != words[1]
    throw(ParseError("Expected format line to begin with \"format\". The line is instead " * format_line))
  end
  Header(words[2], words[3])
end

export header
function header(f)
  # check magic number
  f_magic = readbytes(f, 4)
  if f_magic[4] == '\r'
    # looks like Windows \r\n bull, so read another byte
    f_magic[4] = read(f, Uint8)
  end
  if f_magic != MAGIC.data
    throw(ParseError("Bad magic number: " * string(f_magic)))
  end

  hdr = Header(readline(f))
  lines_read = 2

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
      continue

    elseif words[1] == "end_header"
      break

    else
      throw(ParseError("Unknown header line on line $lines_read"))
    end
  end # eachline(f)

  return hdr
end # function header

Base.string(p::PLY.Property) = "$(p.name)::$(string(p.typ))"
Base.string(p::PLY.ListProperty) = "$(p.name)::Vector{$(string(p.typ))}"

function julia_type(e::PLY.Element)
  str = "immutable Element_$(e.name)\n"
  for p = e.properties
    str *= "\t$(string(p))\n"
  end
  str *= "end"
end

export expr
expr(p::PLY.Property) = :($(p.name) :: $(p.typ))
expr(p::PLY.ListProperty) = :($(p.name) :: Vector{$(p.typ)})

expr(e::PLY.Element) = begin
  ret = parse("immutable $(string(e.name))
#     $(map(expr, e.properties))
    end")
  ret.args[3].args = map(expr, e.properties)
#   ret.args[2].args[3].args = map(expr, e.properties)
  ret
end

export instantiate_types
function instantiate_types(h::PLY.Header)
  types = map(PLY.expr, h.elements)   # build expressions for each type
  map(PLY.eval, types)                    # instantiate the types
  map(t -> PLY.eval(t.args[2]), types)    # return a DataType for each type
end

get_type(e::Element) = PLY.eval(e.name)

function read_ascii(AProperty)

function read_ascii(f::IO, e::Element)
  typ = get_type(e)
  data = Array(typ, e.count)
  for i=1:e.count
    val_strs = split(readline(f))
    it = start(val_strl)



end # module
