#!/usr/bin/env ruby

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers/message/field'

describe ProtocolBuffers, "fields" do

  def mkfield(ftype)
    ProtocolBuffers::Field.const_get(ftype).new(:optional, "test", 1)
  end

  it "checks bounds on varint field types" do
    u32 = mkfield(:Uint32Field)
    u32.valid?(0xFFFFFFFF).should == true
    u32.valid?(0x100000000).should == false
    u32.valid?(-1).should == false

    u64 = mkfield(:Uint64Field)
    u64.valid?(0xFFFFFFFF_FFFFFFFF).should == true
    u64.valid?(0x100000000_00000000).should == false
    u64.valid?(-1).should == false
  end

  it "verifies UTF-8 for string fields" do
    pending("do UTF-8 validation") do
      s1 = mkfield(:StringField)
      s1.valid?("hello").should == true
      b1 = mkfield(:BytesField)
      b1.valid?("\xff\xff").should == true
      s1.valid?("\xff\xff").should == false
    end
  end

end
