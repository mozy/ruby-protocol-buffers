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
    if RUBY_VERSION < "1.9"
      pending "UTF-8 validation only happens in ruby 1.9+"
    else
      good = proc { StringIO.new("hello") }
      bad  = proc { StringIO.new("\xff\xff") }

      s1 = mkfield(:StringField)
      s1.deserialize(good[]).should == "hello"
      s1.deserialize(good[]).encoding.should == Encoding.find('utf-8')
      proc { s1.check_valid(s1.deserialize(good[])) }.should_not raise_error()
      s1.deserialize(bad[]).encoding.should == Encoding.find('utf-8')
      proc { s1.check_valid(s1.deserialize(bad[])) }.should raise_error(ArgumentError)

      b1 = mkfield(:BytesField)
      b1.deserialize(good[]).should == "hello"
      b1.deserialize(good[]).encoding.should == Encoding.find("us-ascii")
      b1.deserialize(bad[]).encoding.should == Encoding.find("binary")
      proc { b1.check_valid(b1.deserialize(bad[])) }.should_not raise_error()
    end
  end

  it "provides a reader for proxy_class on message fields" do
    ProtocolBuffers::Field::MessageField.new(nil, :optional, :fake_name, 1).should respond_to(:proxy_class)
    ProtocolBuffers::Field::MessageField.new(Class, :optional, :fake_name, 1).proxy_class.should == Class
  end
end
