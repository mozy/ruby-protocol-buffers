#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'
require 'protocol_buffers/compiler'

describe ProtocolBuffers, "compiler" do

  test_files = Dir[File.join(File.dirname(__FILE__), "proto_files", "*.proto")]

  test_files.each do |file|
    it "can compile #{File.basename(file)}" do
      proc do
        ProtocolBuffers::Compiler.compile_and_load(file)
      end.should_not raise_error()
    end
  end

end
