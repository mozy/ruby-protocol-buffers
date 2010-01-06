module ProtocolBuffers
  VERSION = File.read(File.join(File.dirname(__FILE__), "..", "VERSION")).chomp
end

require 'protocol_buffers/runtime/message'
