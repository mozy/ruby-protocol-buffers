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
    a1.value_for_tag?(a1.class.field_for_name(:sub1).tag).should == true
    a1.value_for_tag?(a1.class.field_for_name(:sub2).tag).should == false
    a1.value_for_tag?(a1.class.field_for_name(:sub3).tag).should == false

    a1.has_sub1?.should == true
    a1.has_sub2?.should == false
    a1.has_sub3?.should == false
  end

  it "doesn't allow defining fields after gen_methods is called" do
    proc do
      A.define_field(:optional, :string, "newfield", 15)
    end.should raise_error()
  end

end
