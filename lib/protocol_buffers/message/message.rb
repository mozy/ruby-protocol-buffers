require 'stringio'
require 'protocol_buffers/message/field'
require 'protocol_buffers/message/decoder'

module ProtocolBuffers
  class Message
    # Create a new Message of this class.
    #
    # :call-seq:
    #   message = MyMessageClass.new(attributes)
    #   # is equivalent to
    #   message = MyMessageClass.new
    #   message.attributes = attributes
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

    # Serialize this Message to the given IO stream using the Protocol Buffer
    # wire format.
    #
    # Returns +io+
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
      io
    end

    # Serialize this Message to a String and return it.
    def serialize_to_string
      sio = StringIO.new
      serialize(sio)
      return sio.string
    end
    alias_method :to_s, :serialize_to_string

    # Parse a Message of this class from the given IO/String. Since Protocol
    # Buffers are not length delimited, this will read until the end of the
    # stream.
    #
    # This does not call clear! beforehand, so this is logically equivalent to
    # :call-seq:
    #   new_message = self.class.new
    #   new_message.parse(io)
    #   merge_from(new_message)
    def parse(io_or_string)
      io = io_or_string
      if io.is_a?(String)
        io = StringIO.new(io)
      end
      ProtocolBuffers::Decoder.new(io, self).decode
      return self
    end

    # Shortcut, simply calls self.new.parse(io)
    def self.parse(io)
      self.new.parse(io)
    end

    # Merge the attribute values from +obj+ into this Message, which must be of
    # the same class.
    #
    # Singular fields will be overwritten, except for embedded messages which
    # will be merged. Repeated fields will be concatenated.
    def merge_from(obj)
      raise("Incompatible merge types: #{self.class} and #{obj.class}") unless obj.is_a?(self.class)
      for tag, field in self.class.fields
        next unless obj.value_for_tag?(tag)
        value = obj.value_for_tag(tag)
        merge_field(tag, value, field)
      end
    end

    # Parse the string into a new Message of this class, and merge it into the
    # current message like +merge_from+.
    def merge_from_string(string)
      merge_from(self.class.new.parse(string))
    end

    # Assign values to attributes in bulk.
    #
    # :call-seq:
    #   message.attributes = { :field1 => value1, :field2 => value2 } -> message
    def attributes=(hash = {})
      hash.each do |name, value|
        self.send("#{name}=", value)
      end
      self
    end

    # Comparison by class and field values.
    def ==(obj)
      return false unless obj.is_a?(self.class)
      fields.each do |tag, field|
        return false unless self.__send__(field.name) == obj.__send__(field.name)
      end
      return true
    end

    # Reset all fields to the default value.
    def clear!
      fields.each { |tag, field| self.__send__("#{field.name}=", nil) }
    end

    # This is a shallow copy.
    def dup
      ret = self.class.new
      fields.each do |tag, field|
        val = self.__send__(field.name)
        ret.__send__("#{field.name}=", val)
      end
      return ret
    end

    # Returns a hash of { tag => ProtocolBuffers::Field }
    def self.fields
      @fields || @fields = {}
    end

    # Returns a hash of { tag => ProtocolBuffers::Field }
    def fields
      self.class.fields
    end

    # Find the field for the given attribute name. Returns a
    # ProtocolBuffers::field
    def self.field_for_name(name)
      name = name.to_sym
      field = fields.find { |tag,field| field.name == name }
      field && field.last
    end

    # Equivalent to fields[tag]
    def self.field_for_tag(tag)
      fields[tag]
    end

    # Reflection: get the attribute value for the given tag id.
    # :call-seq:
    #   message.value_for_tag(message.class.field_for_name(:f1).tag)
    #   # is equivalent to
    #   message.f1
    def value_for_tag(tag)
      self.__send__(fields[tag].name)
    end

    # :call-seq:
    #   message.value_for_tag?(message.class.field_for_name(:f1).tag)
    #   # is equivalent to
    #   message.has_f1?
    def value_for_tag?(tag)
      @set_fields[tag] || false
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

    def set_field_from_wire(tag, bytes) # :nodoc:
      field = fields[tag]
      value = field.decode(bytes)
      merge_field(tag, value, field)
    end

    def merge_field(tag, value, field = fields[tag]) # :nodoc:
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

    def self.define_field(otype, type, name, tag, opts = {}) # :NODOC:
      raise("gen_methods! already called! cannot add more fields") if @methods_generated
      type = type.is_a?(Module) ? type : type.to_sym
      name = name.to_sym
      tag  = tag.to_i
      raise("Field already exists for tag: #{tag}") if fields[tag]
      field = Field.create(self, otype, type, name, tag, opts)
      fields[tag] = field
      field.add_methods_to(self)
    end

    def self.required(type, name, tag, opts = {}) # :NODOC:
      define_field(:required, type, name, tag, opts)
    end

    def self.optional(type, name, tag, opts = {}) # :NODOC:
      define_field(:optional, type, name, tag, opts)
    end

    def self.repeated(type, name, tag, opts = {}) # :NODOC:
      define_field(:repeated, type, name, tag, opts)
    end

    # Generate the initialize and merge_field methods using reflection, to
    # improve speed. This is called by the generated .pb.rb code, it's not
    # necessary to call this method directly.
    def self.gen_methods! # :NODOC:
      @methods_generated = true

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

  end
end
