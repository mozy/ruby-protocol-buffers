module ProtocolBuffers

  class Decoder # :nodoc: all
    def initialize(io, message)
      @io = io
      @message = message
    end

    def decode(io = @io, message = @message)
      until io.eof?

        tag_int = Varint.decode(io)
        tag = tag_int >> 3
        wire_type = tag_int & 0b111

        # This is ugly magic-number code. These values are defined in
        # field.rb, but believe it or not this loop is so performance critical
        # that just removing the stupid const lookups on each interation shaved
        # 10% off of our decoding benchmark.
        #
        # Besides, these constants can't change without breaking wire protcol
        # compatibility.
        bytes = case wire_type
                when 0 # ProtocolBuffers::WireTypes::VARINT
                  Varint.decode(io)
                when 1 # ProtocolBuffers::WireTypes::FIXED64
                  io.read(8)
                when 2 # ProtocolBuffers::WireTypes::LENGTH_DELIMITED
                  len = Varint.decode(io)
                  io.read(len)
                when 5 # ProtocolBuffers::WireTypes::FIXED32
                  io.read(4)
                else
                  raise "Wire type unknown: #{wire_type}"
                end
        message.set_field_from_wire(tag, bytes)
      end
      return message
    end
  end

end
