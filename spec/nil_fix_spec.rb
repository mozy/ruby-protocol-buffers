# Test by Mark Herman, II <mherman@iseatz.com>
#
# This is a test to demonstrate a significant bug with the handling of nil
# values.  I will be contributing a fix that will cause these tests to pass.

# Here is an explanation of the bug...

# There is an array called @set_fields in our protobuf Message class.
# The Field class (field.rb) adds field accessors to the Message class that incorrect
# call delete_at on @set_fields rather than setting the value to false when a nil
# value is passed.  So, @set_fields shrinks from the end rather than getting false
# values in the proper place.  As more fields are set to nil, the Message class
# thinks fewer and fewer fields are set.  The value_for_tag? method depends on the
# value of @set_fields.  The encoder depends on value_for_tag?.  So, as more nils
# are set, the encoded protobuffers shrink.  The data isn't actually lost.  It's
# never encoded.

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'protocol_buffers'
require 'base64'

# This is a compiled Ruby protobuffer class that will demonstrate the bug
# with the handling of nil classes.

class TestMessage < ::ProtocolBuffers::Message
  optional :string, :field1, 1
  optional :string, :field2, 2

  gen_methods! # new fields ignored after this point
end

describe "Error in nil handling" do
  it "will flag field2 as not having a value when setting field1 to nil" do
    tp = TestMessage.new  # a test protobuffer
    tp.field1 = "field1_value"
    tp.field2 = "field2_value"
    
    tp.field1 = nil
    
    tp.value_for_tag?(2).should be_true
  end
  
  it "will still encode field2 after setting field1 to nil twice" do
    tp = TestMessage.new  # a test protobuffer
    tp.field1 = "field1_value"
    tp.field2 = "field2_value"
    
    tp.field1 = nil
    tp.field1 = nil
    
    Base64.encode64(tp.to_s).length.should be > 0
  end
end