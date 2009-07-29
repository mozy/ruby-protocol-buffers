# TODO: types are not checked for repeated fields

require 'ruby_protobufs'

module Protobuf
  class InvalidFieldValue < StandardError; end

  module WireTypes
    VARINT = 0
    FIXED64 = 1
    LENGTH_DELIMITED = 2
    START_GROUP = 3 # deprecated, not supported in ruby
    END_GROUP = 4   # ditto
    FIXED32 = 5
  end

  module Varint
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
          raise("Too many bytes when decoding varint") if shift >= 64
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

  class Field
    attr_reader :otype, :name, :tag

    def repeated?; otype == :repeated end

    def self.create(sender, otype, type, name, tag, opts = {})
      if type.is_a?(Symbol)
        klass = Field.const_get("#{type.to_s.capitalize}Field") rescue nil
        raise("Type not found: #{type}") if klass.nil?
        field = klass.new(otype, name, tag, opts)
      elsif type.ancestors.include?(Protobuf::Enum)
        field = Field::EnumField.new(type, otype, name, tag, opts)
      elsif type.ancestors.include?(Protobuf::Message)
        field = Field::MessageField.new(type, otype, name, tag, opts)
      else
        raise("Type not found: #{type}")
      end
      return field
    end

    def initialize(otype, name, tag, opts = {})
      @otype = otype
      @name = name
      @tag = tag
      @opts = opts.dup
    end

    def add_methods_to(klass)
      klass.class_eval <<-EOF, __FILE__, __LINE__+1
        attr_reader :#{name}
      EOF
      if repeated?
        klass.class_eval <<-EOF, __FILE__, __LINE__+1
          def #{name}=(value)
            if value.nil?
              @#{name}.clear
            else
              @#{name} = value.dup
            end
          end
        EOF
      else
        klass.class_eval <<-EOF, __FILE__, __LINE__+1
          def #{name}=(value)
            if value.nil?
              @set_fields.delete_at(#{tag})
              @#{name} = fields[#{tag}].default_value
            else
              field = fields[#{tag}]
              raise ::Protobuf::InvalidFieldValue unless field.valid?(value)
              @set_fields[#{tag}] = true
              @#{name} = value
            end
          end
        EOF
      end
    end

    def serialize(io, value)
      # write tag
      Protobuf::Varint.encode(io, (self.tag << 3) | self.class.wire_type)
    end

    def valid?(value)
      true
    end

    def inspect_value(value)
      value.inspect
    end

    class BytesField < Field
      def self.wire_type
        Protobuf::WireTypes::LENGTH_DELIMITED
      end

      def valid?(value)
        value.is_a?(String)
      end

      def default_value
        @opts[:default] || ""
      end

      def serialize(io, value)
        super
        # encode length
        Protobuf::Varint.encode(io, value.length)
        io.write(value)
      end

      def decode(bytes)
        bytes
      end
    end

    class StringField < BytesField; end

    class NumericField < Field
      def min
        0
      end

      def max
        1.0 / 0.0
      end

      def valid?(value)
        value >= min && value <= max
      end

      def default_value
        @opts[:default] || 0
      end
    end

    class VarintField < NumericField
      def self.wire_type
        Protobuf::WireTypes::VARINT
      end

      def serialize(io, value)
        super
        Protobuf::Varint.encode(io, value)
      end

      # this isn't very symmetrical...
      def decode(value)
        value
      end
    end

    class Uint32Field < VarintField
      def max
        0xFFFFFFFF
      end
    end

    class Uint64Field < VarintField
      def max
        0xFFFFFFFF_FFFFFFFF
      end
    end

    class Fixed32Field < NumericField
      def self.wire_type
        Protobuf::WireTypes::FIXED32
      end

      def max
        0xFFFFFFFF
      end

      def serialize(io, value)
        super
        io.write([value].pack('L'))
      end

      def decode(bytes)
        bytes.unpack('L').first
      end
    end

    class Fixed64Field < NumericField
      def self.wire_type
        Protobuf::WireTypes::FIXED64
      end

      def max
        0xFFFFFFFF_FFFFFFFF
      end

      def serialize(io, value)
        super
        io.write([value].pack('Q'))
      end

      def decode(bytes)
        bytes.unpack('Q').first
      end
    end

    class Int32Field < VarintField
      def min
        -(1 << 31)
      end

      def max
        (1 << 31) - 1
      end
    end
    class Sint32Field < Int32Field
      def serialize(io, value)
        super(io, Varint.encodeZigZag32(value))
      end

      def decode(value)
        Varint.decodeZigZag32(super)
      end
    end

    class Sfixed32Field < Fixed32Field
      def min
        -(1 << 31)
      end

      def max
        (1 << 31) - 1
      end

      def serialize(io, value)
        super
        io.write([value].pack('l'))
      end

      def decode(bytes)
        bytes.unpack('l').first
      end
    end

    class Int64Field < VarintField
      def min
        -(1 << 63)
      end

      def max
        (1 << 63) - 1
      end
    end
    class Sint64Field < Int64Field
      def serialize(io, value)
        super(io, Varint.encodeZigZag64(value))
      end

      def decode(value)
        Varint.decodeZigZag64(super)
      end
    end

    class Sfixed64Field < Fixed64Field
      def min
        -(1 << 63)
      end

      def max
        (1 << 63) - 1
      end

      def serialize(io, value)
        super
        io.write([value].pack('q'))
      end

      def decode(bytes)
        bytes.unpack('q').first
      end
    end

    class BoolField < VarintField
      def serialize(io, value)
        super(io, value ? 1 : 0)
      end

      def valid?(value)
        value == true || value == false
      end

      def decode(value)
        value != 0
      end

      def default_value
        @opts[:default] || false
      end
    end

    class EnumField < Int32Field
      attr_reader :valid_values, :value_to_name

      def initialize(proxy_enum, otype, name, tag, opts = {})
        super(otype, name, tag, opts)
        @proxy_enum = proxy_enum
        @valid_values = @proxy_enum.constants.map { |c| @proxy_enum.const_get(c) }.sort
        @value_to_name = @proxy_enum.constants.inject({}) { |h, c|
          h[@proxy_enum.const_get(c)] = c.to_s; h
        }
      end

      def valid?(value)
        @valid_values.include?(value)
      end

      def default_value
        @opts[:default] || @valid_values.first
      end

      def inspect_value(value)
        "#{@value_to_name[value]}(#{value})"
      end
    end

    class MessageField < Field
      def self.wire_type
        Protobuf::WireTypes::LENGTH_DELIMITED
      end

      def initialize(proxy_class, otype, name, tag, opts = {})
        super(otype, name, tag, opts)
        @proxy_class = proxy_class
      end

      def default_value
        @proxy_class.new
      end

      def valid?(value)
        value.is_a?(@proxy_class)
      end

      # TODO: serialize and decode could be made faster if they used
      #       the underlying stream directly rather than string copying
      def serialize(io, value)
        super
        string = value.to_s
        # encode length
        Protobuf::Varint.encode(io, string.length)
        io.write(string)
      end

      def decode(value)
        obj = @proxy_class.new
        obj.parse_from_string(value)
      end
    end

  end
end
