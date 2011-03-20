require 'bundler'
Bundler::GemHelper.install_tasks

task :default => 'spec'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "-c -f d"
end
RSpec::Core::RakeTask.new(:rcov) do |t|
  t.rspec_opts = "-c -f d"
  t.rcov = true
  t.rcov_opts = ["--exclude", "spec,gems/,rubygems/"]
end

require 'yard'
YARD::Rake::YardocTask.new(:doc) do |t|
  version = ProtocolBuffers::VERSION
  t.options = ["--title", "ruby protocol buffers #{version}", "--files", "LICENSE,Changelog.md"]
end
