#!/usr/bin/env ruby

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'
require 'protocol_buffers/compiler'

ProtocolBuffers::Compiler.compile_and_load(
  File.join(File.dirname(__FILE__), "proto_files", "simple.proto"))
ProtocolBuffers::Compiler.compile_and_load(
  File.join(File.dirname(__FILE__), "proto_files", "featureful.proto"))

describe ProtocolBuffers, "runtime" do

  it "can handle basic operations" do

    msg1 = Simple::Test1.new
    msg1.test_field.should == ""

    msg1.test_field = "zomgkittenz"

    msg2 = Simple::Test1.parse(StringIO.new(msg1.to_s))
    msg2.test_field.should == "zomgkittenz"
    msg2.should == msg1
  end

  it "flags values that have been set" do
    a1 = Featureful::A.new
    a1.has_i2?.should == false
    a1.i2 = 5
    a1.has_i2?.should == true
  end

  it "flags sub-messages that have been set" do
    a1 = Featureful::A.new
    a1.value_for_tag?(a1.class.field_for_name(:sub1).tag).should == true
    a1.value_for_tag?(a1.class.field_for_name(:sub2).tag).should == false
    a1.value_for_tag?(a1.class.field_for_name(:sub3).tag).should == false

    a1.has_sub1?.should == true
    a1.has_sub2?.should == false
    a1.has_sub3?.should == false

    a1.sub2 = Featureful::A::Sub.new(:payload => "ohai")
    a1.has_sub2?.should == true
  end

  it "does type checking of repeated fields" do
    pending("do type checking of repeated fields") do
      a1 = Featureful::A.new
      proc do
        a1.sub1 << "dummy string"
      end.should raise_error(ProtocolBuffers::InvalidFieldValue)
    end
  end

  it "detects changes to a sub-message and flags it as set if it wasn't" do
    pending("figure out what to do about sub-message init") do
      # the other option is to start sub-messages as nil, and require explicit
      # instantiation of them. hmm which makes more sense?
      a1 = Featureful::A.new
      a1.has_sub2?.should == false
      a1.sub2.payload = "ohai"
      a1.has_sub2?.should == true
    end
  end

  it "shouldn't modify the default Message instance like this" do
    a1 = Featureful::A.new
    a1.sub2.payload = "ohai"
    a2 = Featureful::A.new
    a2.sub2.payload.should == ""
    sub = Featureful::A::Sub.new
    sub.payload.should == ""
  end

  it "doesn't allow defining fields after gen_methods is called" do
    proc do
      A.define_field(:optional, :string, "newfield", 15)
    end.should raise_error()
  end

  def filled_in_bit
    bit = Featureful::ABitOfEverything.new
    bit.double_field = 1.0
    bit.float_field = 2.0
    bit.int32_field = 3
    bit.int64_field = 4
    bit.uint32_field = 5
    bit.uint64_field = 6
    bit.sint32_field = 7
    bit.sint64_field = 8
    bit.fixed32_field = 9
    bit.fixed64_field = 10
    bit.sfixed32_field = 11
    bit.sfixed64_field = 12
    bit.bool_field = true
    bit.string_field = "14"
    bit.bytes_field = "15"
    bit
  end

  it "can serialize and de-serialize all basic field types" do
    bit = filled_in_bit

    bit2 = Featureful::ABitOfEverything.parse(bit.to_s)
    bit.should == bit2
    bit.fields.each do |tag, field|
      bit.value_for_tag(tag).should == bit2.value_for_tag(tag)
    end
  end

  it "does type checking" do
    bit = filled_in_bit

    proc do
      bit.fixed32_field = 1.0
    end.should raise_error(ProtocolBuffers::InvalidFieldValue)

    proc do
      bit.double_field = 15
    end.should_not raise_error()
    bit2 = Featureful::ABitOfEverything.parse(bit.to_s)
    bit2.double_field.should == 15
    bit2.double_field.should == 15.0
    bit2.double_field.is_a?(Float).should == true

    proc do
      bit.bool_field = 1.0
    end.should raise_error(ProtocolBuffers::InvalidFieldValue)

    proc do
      bit.string_field = 1.0
    end.should raise_error(ProtocolBuffers::InvalidFieldValue)

    a1 = Featureful::A.new
    proc do
      a1.sub2 = "zomgkittenz"
    end.should raise_error(ProtocolBuffers::InvalidFieldValue)
  end

end
