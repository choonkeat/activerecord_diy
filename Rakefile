begin
  require "rubygems"
  require "bundler"
rescue LoadError
  raise "Could not load the bundler gem. Install it with `gem install bundler`."
end

if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("1.0.0")
  raise RuntimeError, "Your bundler version is too old for Mail" +
   "Run `gem install bundler` to upgrade."
end

begin
  # Set up load paths for all bundled gems
  ENV["BUNDLE_GEMFILE"] = File.expand_path("../Gemfile", __FILE__)
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems." +
    "Did you run `bundle install`?"
end

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec

require "activerecord_diy/version"

task :build => :spec do
  # seq = File.exists?(".version") && (IO.read(".version").to_i + 1) || 1
  # content = IO.read("lib/VERSION").gsub(/build:.*/, "build:#{seq}")
  # open("lib/VERSION","w") {|f| f.write(content)}
  # open(".version","w") {|f| f.write(seq.to_s)}
  system "gem build activerecord_diy.gemspec"
end

task :release => :build do
  system "gem push activerecord_diy-ActiverecordDIY::VERSION::STRING"
end
