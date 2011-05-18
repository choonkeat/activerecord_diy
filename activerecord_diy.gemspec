require File.dirname(__FILE__) + "/lib/activerecord_diy/version"

Gem::Specification.new do |s|
  s.name        = "activerecord_diy"
  s.version     = ActiverecordDIY::VERSION::STRING
  s.authors     = ["Chew Choon Keat"]
  s.email       = ["choonkeat@gmail.com"]
  s.homepage    = "http://github.com/choonkeat/activerecord_diy"
  s.license     = 'MIT'
  s.description = "Cheap replacement for friendlyorm in Rails 3"
  s.summary     = "Allows ActiveRecord models to use external table as index; allows storing of variable schema using a single json column"

  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.md", "CHANGELOG.md"]

  s.add_dependency('mysql2', ">= 0.2.7")
  s.add_dependency('activesupport', ">= 3.0.6")
  s.add_dependency('activerecord', ">= 3.0.6")
  s.add_dependency('delayed_job', ">= 2.1.4")
  s.add_dependency('uuid', ">= 2.3.2")

  s.add_development_dependency("rspec", ">= 2.5.0")
  s.add_development_dependency("ZenTest", ">= 4.5.0")
  s.add_development_dependency("rake", ">= 0.8.7")
  s.add_development_dependency("bundler", ">= 1.0.12")

  s.require_path = 'lib'
  s.files = %w(LICENSE README.md Rakefile) + Dir.glob("lib/**/*")
end
