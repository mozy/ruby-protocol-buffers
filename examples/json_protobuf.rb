#!/usr/bin/env ruby

# Example JSON/Protocol Buffer conversion using reflection.
# Requires the json gem.

begin
  require 'rubygems'
rescue LoadError; end

require 'json'
$LOAD_PATH << File.dirname(__FILE__) + '/../lib'
require 'protocol_buffers'
require 'protocol_buffers/compiler'

class ProtocolBuffers::Message

  def to_json(*args)
    hash = {'json_class' => self.class.name}

    # simpler version, includes all fields in the output, using the default
    # values if unset. also includes empty repeated fields as empty arrays.
    # fields.each do |tag, field|
    #   hash[field.name] = value_for_tag(field.tag)
    # end

    # prettier output, only includes non-empty repeated fields and set fields
    fields.each do |tag, field|
      if field.repeated?
        value = value_for_tag(field.tag)
        hash[field.name] = value unless value.empty?
      else
        hash[field.name] = value_for_tag(field.tag) if value_for_tag?(field.tag)
      end
    end
    hash.to_json(*args)
  end

  def self.json_create(hash)
    hash.delete('json_class')

    # initialize takes a hash of { attribute_name => value } so you can just
    # pass the hash into the constructor. but we're supposed to be showing off
    # reflection, here. plus, that raises an exception if there is an unknown
    # key in the hash.
    # new(hash)

    message = new
    fields.each do |tag, field|
      if value = hash[field.name.to_s]
        message.set_value_for_tag(field.tag, value)
      end
    end
    message
  end
end

# and that's it... all the rest of this code is just to show it off

ProtocolBuffers::Compiler.compile_and_load_string <<-EOS
message Foo {
  enum Bar {
    A = 1;
    B = 2;
    C = 3;
  };

  message Baz {
    optional string subby = 1;
  };

  repeated Bar bars = 1;
  optional string name = 2;
  repeated string bazzesses = 3;
  optional Baz subbaz = 4;
};
EOS

foo = Foo.new(:name => 'foo1')
foo.bars += [Foo::Bar::A, Foo::Bar::A, Foo::Bar::C]
foo.subbaz = Foo::Baz.new(:subby => "subby!")

puts "Input protobuf:", foo.inspect, ""

json = JSON.pretty_generate(foo)
puts "JSON representation:", json, ""

foo2 = JSON.parse(json)
puts "Parsed from JSON:", foo2.inspect, ""

puts "Are they equal: #{foo == foo2}"
