require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers/runtime/field'

describe ProtocolBuffers, "fields" do

  def mkfield(ftype)
    ProtocolBuffers::Field.const_get(ftype).new(:optional, "test", 1)
  end

  it "checks bounds on varint field types" do
    u32 = mkfield(:Uint32Field)
    proc { u32.check_valid(0xFFFFFFFF) }.should_not raise_error()
    proc { u32.check_valid(0x100000000) }.should raise_error(ArgumentError)
    proc { u32.check_valid(-1) }.should raise_error(ArgumentError)

    u64 = mkfield(:Uint64Field)
    proc { u64.check_valid(0xFFFFFFFF_FFFFFFFF) }.should_not raise_error()
    proc { u64.check_valid(0x100000000_00000000) }.should raise_error(ArgumentError)
    proc { u64.check_valid(-1) }.should raise_error(ArgumentError)
  end

  it "properly encodes and decodes negative varints" do
    val = -2082844800000000
    str = "\200\300\313\274\236\265\246\374\377\001"
    sio = ProtocolBuffers.bin_sio
    ProtocolBuffers::Varint.encode(sio, val)
    sio.string.should == str
    sio.rewind
    val2 = ProtocolBuffers::Varint.decode(sio)
    int64 = mkfield(:Int64Field)
    int64.deserialize(val2).should == val
    proc { int64.check_value(int64.deserialize(val2)) }.should_not raise_error
  end

  it "verifies UTF-8 for string fields" do
    pending("do UTF-8 validation") do
      s1 = mkfield(:StringField)
      proc { s1.check_valid("hello") }.should_not raise_error()
      proc { s1.check_valid("\xff\xff") }.should raise_error(ArgumentError)
      b1 = mkfield(:BytesField)
      proc { b1.check_valid("\xff\xff") }.should_not raise_error()
    end
  end

end
