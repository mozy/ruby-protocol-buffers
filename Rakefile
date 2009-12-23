require 'rubygems'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = "ruby-protocol-buffers"
  s.version = "0.1.0"
  s.author = "Brian Palmer"
  s.email = "brian@mozy.com"
  s.homepage = "http://todo"
  s.platform = Gem::Platform::RUBY
  s.summary = "Ruby compiler and runtime for the google protocol buffers library. Currently includes a compiler that utilizes protoc."

  s.required_ruby_version = ">=1.8.6"

  s.files = FileList["{bin,lib,ext}/**/*"].to_a
  s.require_path = 'lib'
  s.executables << 'ruby-protoc'
  # disabled to avoid needing to compile a C extension just to boost
  # performance. TODO: is there a way to tell gems to make the extension
  # optional?
  # s.extensions << 'ext/extconf.rb'
end

Rake::GemPackageTask.new(spec) do |pkg|
end

task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
    puts "generated latest version"
end
