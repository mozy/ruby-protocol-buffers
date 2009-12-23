#!/usr/bin/env ruby

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'
require 'protocol_buffers/compiler'

describe ProtocolBuffers, "runtime" do

  it "can handle basic operations" do
    ProtocolBuffers::Compiler.compile_and_load(
      File.join(File.dirname(__FILE__), "proto_files", "simple.proto"))

    msg1 = Simple::Test1.new
    msg1.test_field.should == ""

    msg1.test_field = "zomgkittenz"

    msg2 = Simple::Test1.parse(StringIO.new(msg1.to_s))
    msg2.test_field.should == "zomgkittenz"
    msg2.should == msg1
  end

  it "flags values that have been set" do
    ProtocolBuffers::Compiler.compile_and_load(
      File.join(File.dirname(__FILE__), "proto_files", "featureful.proto"))

    a1 = Featureful::A.new
    a1.value_for_tag?(a1.class.field_for_name(:sub1).first).should == true
    a1.value_for_tag?(a1.class.field_for_name(:sub2).first).should == false
    a1.value_for_tag?(a1.class.field_for_name(:sub3).first).should == false
  end

end
