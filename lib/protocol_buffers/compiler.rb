require 'protocol_buffers/compiler/descriptor.pb'

module ProtocolBuffers
  class CompileError < Exception; end

  module Compiler
    def self.compile(output_filename, input_files, opts = {})
      input_files = Array(input_files) unless input_files.is_a?(Array)
      raise(ArgumentError, "Need at least one input file") if input_files.empty?
      other_opts = ""
      (opts[:include_dirs] || []).each { |d| other_opts += " -I#{d}" }

      cmd = "protoc #{other_opts} -o#{output_filename} #{input_files.join(' ')}"
      rc = system(cmd)
      raise(CompileError, $?.exitstatus.to_s) unless rc
      true
    end

    def self.compile_and_load(input_files, opts = {})
      require 'tempfile'
      require 'protocol_buffers/compiler/file_descriptor_to_ruby'

      tempfile = Tempfile.new("protocol_buffers_spec")
      compile(tempfile.path, input_files, opts)
      descriptor_set = FileDescriptorSet.parse(tempfile)
      tempfile.close(true)
      descriptor_set.file.each do |file|
        parsed = FileDescriptorToRuby.new(file)
        output = Tempfile.new("protocol_buffers_spec_parsed")
        parsed.write(output)
        output.flush
        load output.path
        output.close(true)
      end
      true
    end
  end
end
