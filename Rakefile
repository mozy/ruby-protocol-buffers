require 'rubygems'
require 'rake'
require 'spec'

begin
  require 'metric_fu'
rescue LoadError
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "ruby-protocol-buffers"
    gem.summary = %Q{Ruby compiler and runtime for the google protocol buffers library.}
    gem.homepage = "http://github.com/mozy/ruby-protocol-buffers"
    gem.authors = ["Brian Palmer"]
    gem.version = File.read('VERSION')
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.required_ruby_version = ">=1.8.6"
    gem.require_path = 'lib'
    gem.extra_rdoc_files << "Changelog.md"
    gem.files << "Changelog.md"
    # disabled to avoid needing to compile a C extension just to boost
    # performance. TODO: is there a way to tell gems to make the extension
    # optional?
    # s.extensions << 'ext/extconf.rb'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  # You'll need to install Jeweler to build packages
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ruby-protocol-buffers #{version}"
  rdoc.rdoc_files.include('README*', 'LICENSE')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
