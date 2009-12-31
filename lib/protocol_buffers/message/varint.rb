module ProtocolBuffers

  module Varint # :nodoc:
    # encode/decode methods defined in ext/varint.c

    unless self.respond_to?(:encode)
      def self.encode(io, int_val)
        if int_val < 0
          # negative varints are always encoded with the full 10 bytes
          int_val = int_val & 0xffffffff_ffffffff
        end
        loop do
          byte = int_val & 0b0111_1111
          int_val >>= 7
          if int_val == 0
            io << byte.chr
            break
          else
            io << (byte | 0b1000_0000).chr
          end
        end
      end
    end

    unless self.respond_to?(:decode)
      def self.decode(io)
        int_val = 0
        shift = 0
        loop do
          raise(DecodeError, "too many bytes when decoding varint") if shift >= 64
          byte = io.getbyte
          int_val |= (byte & 0b0111_1111) << shift
          shift += 7
          # int_val -= (1 << 64) if int_val > UINT64_MAX
          return int_val if (byte & 0b1000_0000) == 0
        end
      end
    end

    def self.encodeZigZag32(int_val)
      (int_val << 1) ^ (int_val >> 31)
    end

    def self.encodeZigZag64(int_val)
      (int_val << 1) ^ (int_val >> 63)
    end

    def self.decodeZigZag32(int_val)
      (int_val >> 1) ^ -(int_val & 1)
    end
    class << self; alias_method :decodeZigZag64, :decodeZigZag32 end

  end

end
