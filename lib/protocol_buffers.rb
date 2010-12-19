module ProtocolBuffers
  VERSION = File.read(File.join(File.dirname(__FILE__), "..", "VERSION")).chomp

  require 'stringio'
  # for 1.9.2 compatibility
  def self.bin_sio(*args)
    sio = StringIO.new(*args)
    sio.set_encoding('binary') if sio.respond_to?(:set_encoding)
    sio
  end
end

require 'protocol_buffers/runtime/message'
