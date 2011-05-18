# encoding: utf-8
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

unless defined?(SPEC_ROOT)
  SPEC_ROOT = File.join(File.dirname(__FILE__))
end

require 'activerecord_diy'
ActiveRecord::Base.establish_connection({
  "adapter" => "mysql2",
  "encoding" => "utf8",
  "reconnect" => false,
  "database" => "activerecord_diy_test",
  "pool" => "5",
  "username" => "root",
  "password" => "",
  "socket" => "/tmp/mysql.sock",
})
ActiveRecord::Base.connection.instance_eval do
  create_table :delayed_jobs, :force => true do |table|
    table.integer  :priority, :default => 0      # Allows some jobs to jump to the front of the queue
    table.integer  :attempts, :default => 0      # Provides for retries, but still fail eventually.
    table.text     :handler                      # YAML-encoded string of the object that will do work
    table.text     :last_error                   # reason for last failure (See Note below)
    table.datetime :run_at                       # When to run. Could be Time.zone.now for immediately, or sometime in the future.
    table.datetime :locked_at                    # Set when a client is working on this object
    table.datetime :failed_at                    # Set when all retries have failed (actually, by default, the record is deleted instead)
    table.string   :locked_by                    # Who is working on this object (if locked)
    table.timestamps
  end
  add_index :delayed_jobs, [:priority, :run_at], :name => 'delayed_jobs_priority'
end unless ActiveRecord::Base.connection.tables.include?('delayed_jobs')
Delayed::Worker.guess_backend # Delayed::Job
