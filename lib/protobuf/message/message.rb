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
      type = type.is_a?(Module) ? type : type.to_sym
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

    def self.gen_methods!
      self.class_eval <<-EOF, __FILE__, __LINE__+1
        def initialize(attributes = {})
          @set_fields = []

          #{fields.map do |tag, field|
            if field.repeated?
              %{@#{field.name} = []
                @set_fields[#{tag}] = true}
            else
              %{@#{field.name} = fields[#{tag}].default_value}
            end
          end.join("\n")}

          self.attributes = attributes unless attributes.empty?
        end
      EOF

      return if fields.empty?

      self.class_eval <<-EOF, __FILE__, __LINE__+1
        def merge_field(tag, value, field = nil)
          case tag
            #{fields.map do |tag, field|
              %{when #{tag}\n} +
              if field.repeated?
                %{if value.is_a?(Array)
                    @#{field.name} += value
                  else
                    @#{field.name} << value
                  end}
              else
                %{@#{field.name} = value
                  @set_fields[#{tag}] = true}
              end
            end.join("\n")}
          end
        end
      EOF
    end

    def attributes=(hash = {})
      hash.each do |name, value|
        self.send("#{name}=", value)
      end
    end

    def initialize(attributes = {})
      @set_fields = []

      fields.each do |tag, field|
        if field.repeated?
          self.__send__("#{field.name}=", [])
          @set_fields[tag] = true # repeated fields are always "set"
        else
          self.__send__("#{field.name}=", field.default_value)
          @set_fields[tag] = false # hackish -- this is set by the writer
        end
      end

      self.attributes = attributes
    end

    def value_for_tag(tag)
      self.__send__(fields[tag].name)
    end

    def value_for_tag?(tag)
      @set_fields[tag]
    end

    def ==(obj)
      return false unless obj.is_a?(self.class)
      fields.each do |tag, field|
        return false unless self.__send__(field.name) == obj.__send__(field.name)
      end
      return true
    end

    def clear!
      fields.each { |tag, field| self.__send__("#{field.name}=", nil) }
    end

    def dup
      ret = self.class.new
      fields.each do |tag, field|
        val = self.__send__(field.name)
        ret.__send__("#{field.name}=", val)
      end
      return ret
    end

    def inspect
      ret = StringIO.new
      ret << "#<#{self.class.name}"
      fields.each do |tag, field|
        ret << " #{field.name}=#{field.inspect_value(self.__send__(field.name))}"
      end
      ret << ">"
      return ret.string
    end

    def set_field_from_wire(tag, bytes)
      field = fields[tag]
      value = field.decode(bytes)
      merge_field(tag, value, field)
    end

    def merge_field(tag, value, field = fields[tag])
      if field.repeated?
        if value.is_a?(Array)
          self.__send__("#{field.name}=", self.__send__(field.name) + value)
        else
          self.__send__(field.name) << value
        end
      else
        self.__send__("#{field.name}=", value)
        @set_fields[tag] = true
      end
    end

    def parse(io)
      Protobuf::Decoder.new(io, self).decode
      return self
    end

    def self.parse(io)
      self.new.parse(io)
    end

    def serialize(io)
      fields.each do |tag, field|
        next unless @set_fields[tag]
        value = self.__send__(field.name)
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
