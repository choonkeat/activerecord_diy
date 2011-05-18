source :rubygems

# Add your run time dependencies here

group :test do
  gem "ZenTest"
  gem "rake"
  gem "bundler"
  gem "rspec"
  gem "diff-lcs"
  gem "mysql2"
  gem "activesupport"
  gem "activerecord"
  gem "delayed_job"
  gem "uuid"
  case
  when defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
    # Skip it
  when RUBY_PLATFORM == 'java'
    # Skip it
  when RUBY_VERSION < '1.9'
    gem "ruby-debug"
  else
    # Skip it
  end
end
