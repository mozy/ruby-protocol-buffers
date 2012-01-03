# Tests for issues with handling of nil fields in protobuffers

# By Mark Herman <mherman@iseatz.com>

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'

# Without the nil fix, assigning nil to a field would cause the encoder to
# start failing to encode fields.
describe "testing handling of nil assignments to protobuffers" do
  it "should accept nil assignments into a single field without losing other data" do
    # I will assign nil a couple of times and then test whether the protobuffer encodes at all
    test_pb = NilTest.new
    test_pb.test_field_1 = "test_value_1"
    test_pb.test_field_2 = "test_value_2"
    
    test_pb.test_field_1 = nil
    test_pb.test_field_1 = nil
    
    (test_pb.to_s.length > 0).should be_true
  end
end
