module Protobuf

  class Decoder
    def initialize(io, message)
      @io = io
      @message = message
    end

    def decode(io = @io, message = @message)
      until io.eof?
        tag, wire_type = read_tag(io)
        bytes = case wire_type
                when Protobuf::WireTypes::VARINT
                  Protobuf::Varint.decode(io)
                when Protobuf::WireTypes::FIXED64
                  io.read(8)
                when Protobuf::WireTypes::LENGTH_DELIMITED
                  len = Protobuf::Varint.decode(io)
                  io.read(len)
                when Protobuf::WireTypes::FIXED32
                  io.read(4)
                else
                  raise "Wire type unknown: #{wire_type}"
                end
        message.set_field_from_wire(tag, bytes)
      end
      return message
    end

    # returns tag, wire_type
    def read_tag(io)
      int_value = Protobuf::Varint.decode(io)
      return int_value >> 3, int_value & 0b111
    end
  end

end
