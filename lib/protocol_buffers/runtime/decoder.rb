require 'protocol_buffers/limited_io'

module ProtocolBuffers

  class DecodeError < StandardError; end

  module Decoder # :nodoc: all
    def self.decode(io, message)
      fields = message.fields

      until io.eof?
        tag_int = Varint.decode(io)
        tag = tag_int >> 3
        wire_type = tag_int & 0b111
        field = fields[tag]

        if field && wire_type != field.wire_type
          raise(DecodeError, "incorrect wire type for tag: #{field.tag}")
        end

        # replacing const lookups with hard-coded ints removed an entire 10%
        # from an earlier decoding benchmark. these values can't change without
        # breaking the protocol anyway, so we decided it was worth it.
        case wire_type
        when 0 # VARINT
          value = Varint.decode(io)
        when 1 # FIXED64
          value = io.read(8)
        when 2 # LENGTH_DELIMITED
          length = Varint.decode(io)
          value = LimitedIO.new(io, length)
        when 5 # FIXED32
          value = io.read(4)
        when 3, 4 # deprecated START_GROUP/END_GROUP types
          raise(DecodeError, "groups are deprecated and unsupported")
        else
          raise(DecodeError, "unknown wire type: #{wire_type}")
        end

        if field
          deserialized = field.deserialize(value)
          # merge_field handles repeated field logic
          message.merge_field(tag, deserialized, field)
        else
          # ignore unknown fields
          # TODO: save them, pass them on

          # special handling -- if it's a LENGTH_DELIMITED field, we need to
          # actually read the IO so that extra bytes aren't left on the wire
          value.read if wire_type == 2 # LENGTH_DELIMITED
        end
      end

      unless message.valid?
        raise(DecodeError, "invalid message")
      end

      return message
    rescue TypeError, ArgumentError
      raise(DecodeError, "error parsing message")
    end
  end

end
