require 'protocol_buffers'
require 'protocol_buffers/runtime/enum'
require 'protocol_buffers/runtime/varint'
require 'protocol_buffers/limited_io'

module ProtocolBuffers

  module WireTypes # :nodoc:
    VARINT = 0
    FIXED64 = 1
    LENGTH_DELIMITED = 2
    START_GROUP = 3 # deprecated, not supported in ruby
    END_GROUP = 4   # ditto
    FIXED32 = 5
  end

  class Field # :nodoc: all
    attr_reader :otype, :name, :tag

    def repeated?; otype == :repeated end

    def self.create(sender, otype, type, name, tag, opts = {})
      if type.is_a?(Symbol)
        klass = Field.const_get("#{type.to_s.capitalize}Field") rescue nil
        raise("Type not found: #{type}") if klass.nil?
        field = klass.new(otype, name, tag, opts)
      elsif type.ancestors.include?(ProtocolBuffers::Enum)
        field = Field::EnumField.new(type, otype, name, tag, opts)
      elsif type.ancestors.include?(ProtocolBuffers::Message)
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
              @#{name}.clear
              value.each { |i| @#{name} << i }
            end
          end

          def has_#{name}?; true; end
        EOF
      else
        klass.class_eval <<-EOF, __FILE__, __LINE__+1
          def #{name}=(value)
            field = fields[#{tag}]
            if value.nil?
              @set_fields.delete_at(#{tag})
              @#{name} = field.default_value
            else
              field.check_valid(value)
              @set_fields[#{tag}] = true
              @#{name} = value
              if @parent_for_notify
                @parent_for_notify.default_changed(@tag_for_notify)
                @parent_for_notify = @tag_for_notify = nil
              end
            end
          end

          def has_#{name}?
            value_for_tag?(#{tag})
          end
        EOF
      end
    end

    def check_value(value)
      # pass
    end

    def valid_type?(value)
      true
    end

    def inspect_value(value)
      value.inspect
    end

    def check_valid(value)
      raise(TypeError, "can't assign #{value.class.name} to #{self.class.name}") unless valid_type?(value)
      check_value(value)
    end

    # the type of value to return depends on the wire_type of the field:
    # VARINT => Integer
    # FIXED64 => 8-byte string
    # LENGTH_DELIMITED => string
    # FIXED32 => 4-byte string
    def serialize(value)
      value
    end

    # the type of value passed in depends on the wire_type of the field:
    # VARINT => Integer (Fixnum or Bignum)
    # FIXED64 => 8-byte string
    # LENGTH_DELIMITED => IO class, make sure to consume all data available
    # FIXED32 => 4-byte string
    def deserialize(value)
      value
    end

    module WireFormats
      module LENGTH_DELIMITED
        def wire_type
          WireTypes::LENGTH_DELIMITED
        end

        def deserialize(value)
          value.read
        end
      end

      module VARINT
        def wire_type
          WireTypes::VARINT
        end
      end

      module FIXED32
        def wire_type
          WireTypes::FIXED32
        end

        def serialize(value)
          [value].pack(pack_code)
        end

        def deserialize(value)
          value.unpack(pack_code).first
        end
      end

      module FIXED64
        def wire_type
          WireTypes::FIXED64
        end

        def serialize(value)
          [value].pack(pack_code)
        end

        def deserialize(value)
          value.unpack(pack_code).first
        end
      end
    end

    class BytesField < Field
      include WireFormats::LENGTH_DELIMITED

      def valid_type?(value)
        value.is_a?(String)
      end

      def default_value
        @default_value || @default_value = (@opts[:default] || "").freeze
      end
    end

    class StringField < BytesField
      # TODO: UTF-8 validation
    end

    class NumericField < Field
      def min
        0
      end

      def max
        1.0 / 0.0
      end

      def check_value(value)
        raise(ArgumentError, "value is out of range for type #{self.class.name}: #{value}") unless value >= min && value <= max
      end

      def default_value
        @opts[:default] || 0
      end

      private
      # base class, not used directly
      def initialize(*a); super; end
    end

    class VarintField < NumericField
      include WireFormats::VARINT

      def valid_type?(value)
        value.is_a?(Integer)
      end

      private
      # base class, not used directly
      def initialize(*a); super; end
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
      include WireFormats::FIXED32

      def pack_code
        'L'
      end

      def max
        0xFFFFFFFF
      end

      def valid_type?(value)
        value.is_a?(Integer)
      end
    end

    class Fixed64Field < NumericField
      include WireFormats::FIXED64

      def pack_code
        'Q'
      end

      def max
        0xFFFFFFFF_FFFFFFFF
      end

      def valid_type?(value)
        value.is_a?(Integer)
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
      def serialize(value)
        Varint.encodeZigZag32(value)
      end

      def deserialize(value)
        Varint.decodeZigZag32(value)
      end
    end

    class Sfixed32Field < NumericField
      include WireFormats::FIXED32

      def pack_code
        'l'
      end

      def min
        -(1 << 31)
      end

      def max
        (1 << 31) - 1
      end

      def valid_type?(value)
        value.is_a?(Integer)
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
      def serialize(value)
        Varint.encodeZigZag64(value)
      end

      def deserialize(value)
        Varint.decodeZigZag64(value)
      end
    end

    class Sfixed64Field < NumericField
      include WireFormats::FIXED64

      def pack_code
        'q'
      end

      def min
        -(1 << 63)
      end

      def max
        (1 << 63) - 1
      end

      def valid_type?(value)
        value.is_a?(Integer)
      end
    end

    class FloatField < Field
      include WireFormats::FIXED32

      def pack_code
        'e'
      end

      def valid_type?(value)
        value.is_a?(Numeric)
      end

      def default_value
        @opts[:default] || 0.0
      end
    end

    class DoubleField < Field
      include WireFormats::FIXED64

      def pack_code
        'E'
      end

      def valid_type?(value)
        value.is_a?(Numeric)
      end

      def default_value
        @opts[:default] || 0.0
      end
    end

    class BoolField < VarintField
      def serialize(value)
        value ? 1 : 0
      end

      def valid_type?(value)
        value == true || value == false
      end

      def check_value(value); end

      def deserialize(value)
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

      def check_value(value)
        raise(ArgumentError, "value is out of range for #{self.class.name}: #{value}") unless @valid_values.include?(value)
      end

      def default_value
        @opts[:default] || @valid_values.first
      end

      def inspect_value(value)
        "#{@value_to_name[value]}(#{value})"
      end
    end

    class MessageField < Field
      include WireFormats::LENGTH_DELIMITED

      def initialize(proxy_class, otype, name, tag, opts = {})
        super(otype, name, tag, opts)
        @proxy_class = proxy_class
      end

      def default_value
        @proxy_class.new
      end

      def valid_type?(value)
        value.is_a?(@proxy_class)
      end

      # TODO: serialize could be more efficient if it used the underlying stream
      # directly rather than string copying, but that would require knowing the
      # length beforehand.
      def serialize(value)
        value.to_s
      end

      def deserialize(io)
        @proxy_class.parse(io)
      end
    end

  end
end
