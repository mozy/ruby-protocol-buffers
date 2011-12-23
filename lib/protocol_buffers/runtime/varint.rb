module ProtocolBuffers

  module Varint # :nodoc:
    # encode/decode methods defined in ext/varint.c
    unless self.respond_to?(:encode)
      def self.encode(io, int_val)
        if int_val < 0
          # First, note to self...protobufs are encoded little-endian
          # Ruby seems to fake big endian order.
          (1..9).each do |x|
            byte = int_val & 0b0111_1111
            int_val >>= 7
            byte |= 0b1000_0000 if x < 9
            io << byte.chr
          end
        else
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
    end

    unless self.respond_to?(:decode)
      def self.decode(io)
        int_val = 0
        shift = 0
        loop do
          raise(DecodeError, "too many bytes when decoding varint") if shift >= 64
          byte = io.getc.ord
          
          # In a protobuf, the 7 least significant bits are the actual data
          int_val |= (byte & 0b0111_1111) << shift
          shift += 7

          # This flags the last byte, which is also the most significant
          if (byte & 0b1000_0000) == 0
            
            # This is positive...we're done.
            if (byte & 0b0100_0000) == 0
              # A negative number would have had a 1 as the most significant bit
              return int_val
            else
              # This is a negative number.  It needs special handling.  The bits in int_val
              # are correct, but Ruby doesn't know the number is negative.  I can at least
              # get the bits as a string.  Time to do 1's complement on the string.  Best
              # I can do for now.  Wouldn't mind revisiting this.  Ruby's bitwise not turns
              # the fake positive number into the wrong negative number :(
              
              # Let this be a reason to take Google's advice and use sint32 for negative numbers
              bin_val_str = "%b" % int_val # I can at least get correct bits

              # This inverts the "bits"
              bin_val_str = bin_val_str.gsub('0', '2')
              bin_val_str = bin_val_str.gsub('1', '0')
              bin_val_str = bin_val_str.gsub('2', '1')
              
              ones_comp = bin_val_str.to_i(2)

              # I can't seem to find a decent way to do 2's complement.  Hacking a bit...a lot.
              return -(ones_comp + 1)
            end
          end
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

# fix for 1.8 <-> 1.9 compat
unless 'a'.respond_to?(:ord)
  class String; def ord; self[0]; end; end
end
unless (1).respond_to?(:ord)
  class Fixnum; def ord; self; end; end
end
