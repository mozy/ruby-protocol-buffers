# Tests for Unicode issues in protobuffer library.

# By Mark Herman <mherman@iseatz.com> based on code from
# Tom Zetty <tzetty@iseatz.com>

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'

describe "Testing for bugs in Unicode encoding and decoding" do
  # This should always pass
  it "should return the input string given a regular string" do
    validate_pbr(StringTest, "test_string", true).should be_true
  end

  # Encoding objects aren't defined in Ruby 1.8.  This will only run on 1.9 or above.
  # It should fail on Ruby 1.9 without the Unicode fix.
  if ''.respond_to? "encoding"
    it "should return the given UTF8 string" do
      validate_pbr(StringTest, ''.encode(Encoding::UTF_8) + "utf8_rulz", true)
    end
  end

  # This should pass in Ruby 1.8 with the Unicode fix, but it will know nothing of the encoding
  # This should fail without the Unicode fix. The previous implementation was encoding
  # with the character length rather than the byte length.  It was also returning strings
  # with their encoding set to ASCII.  The new code forces it to UTF-8.
  it "should return the given Unicode string" do
    string_with_r = "(R) Char: \u00AE"
    validate_pbr(StringTest, string_with_r, true).should be_true
  end
end
