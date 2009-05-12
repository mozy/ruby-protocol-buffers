require 'stringio'
require 'protobuf/message/field'
require 'protobuf/message/decoder'

# TODO: extension fields

module Protobuf
  class Message

    def self.defined_in(fname)
      @defined_in = fname
    end

    # { tag => Field }
    def self.fields
      @fields || @fields = {}
    end
    def fields; self.class.fields; end

    def self.field_for_name(name)
      name = name.to_sym
      fields.find { |tag,field| field.name == name }
    end

    def self.field_for_tag(tag)
      fields[tag]
    end

    def self.define_field(otype, type, name, tag, opts = {})
      type = type.is_a?(Class) ? type : type.to_sym
      name = name.to_sym
      tag  = tag.to_i
      raise("Field already exists for tag: #{tag}") if fields[tag]
      field = Field.create(self, otype, type, name, tag, opts)
      fields[tag] = field
      field.add_methods_to(self)
    end

    def self.required(type, name, tag, opts = {})
      define_field(:required, type, name, tag, opts)
    end

    def self.optional(type, name, tag, opts = {})
      define_field(:optional, type, name, tag, opts)
    end

    def self.repeated(type, name, tag, opts = {})
      define_field(:repeated, type, name, tag, opts)
    end

    def initialize(attributes = {})
      @values = {}
      @set_fields = {}

      for tag, field in fields
        if field.repeated?
          @values[tag] = []
          @set_fields[tag] = true # repeated fields are always "set"
        else
          @values[tag] = field.default_value
        end
      end

      for name, value in attributes
        # FIXME: lots of yucky string allocations here
        self.send("#{name}=", value)
      end
    end

    def value_for_tag(tag)
      @values[tag]
    end

    def value_for_tag?(tag)
      @set_fields[tag]
    end

    def ==(obj)
      return false unless obj.is_a?(self.class)
      obj_values = obj.instance_variable_get(:@values)
      fields.each do |tag, field|
        return false unless @values[tag] == obj_values[tag]
      end
      return true
    end

    def clear!
      @values.clear
    end

    def dup
      values = @values.dup
      # fix up repeated fields, we don't want to share arrays
      fields.each do |tag, field|
        values[tag] = values[tag].dup if field.repeated?
      end

      ret = self.class.new
      ret.instance_variable_set(:@values, values)
      return ret
    end

    def inspect
      ret = StringIO.new
      ret << "#<#{self.class.name}"
      fields.each do |tag, field|
        ret << " #{field.name}=#{field.inspect_value(@values[tag])}"
      end
      ret << ">"
      return ret.string
    end

    def set_field_from_wire(tag, bytes)
      field = self.class.fields[tag]
      value = field.decode(bytes)
      merge_field(tag, value, field)
    end

    def merge_field(tag, value, field = fields[tag])
      if field.repeated?
        if value.is_a?(Array)
          @values[tag] += value
        else
          @values[tag] << value
        end
      else
        @values[tag] = value
        @set_fields[tag] = true
      end
    end

    def parse(io)
      Protobuf::Decoder.new(io, self).decode
      return self
    end

    def serialize(io)
      for tag, value in @values
        next unless @set_fields[tag]
        field = self.class.fields[tag]
        if field.repeated?
          value.each { |v| field.serialize(io, v) }
        else
          field.serialize(io, value)
        end
      end
    end

    def parse_from_string(string)
      parse(StringIO.new(string))
    end

    def parse_from_file(filename_or_io)
      if filename_or_io.is_a? IO
        parse(filename_or_io)
      else
        File.open(filename_or_io, 'rb') { |f| parse(f) }
      end
    end

    def serialize_to_string
      sio = StringIO.new
      serialize(sio)
      return sio.string
    end
    alias_method :to_s, :serialize_to_string

    def merge_from(obj)
      raise("Incompatible merge types: #{self.class} and #{obj.class}") unless obj.is_a?(self.class)
      for tag, field in self.class.fields
        next unless obj.value_for_tag?(tag)
        value = obj.value_for_tag(tag)
        merge_field(tag, value, field)
      end
    end

    def merge_from_string(string)
      merge_from(self.class.new.parse_from_string(string))
    end

  end
end
