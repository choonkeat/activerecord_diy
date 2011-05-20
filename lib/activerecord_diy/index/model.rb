# encoding: utf-8
module ActiverecordDIY
  module Index
    module Model
      extend ActiveSupport::Concern
      included do
        after_save :update_indexes
      end
      module ClassMethods
        def indexes_for(*cols)
          unscoped.with_implied_columns(cols) do |rel|
            tbl = rel.index_table_name
            key = cols.collect(&:to_s)
            CONFIG[self.table_name].merge!(key => tbl)
          end
        end
        def index_table_wrapper_class(tbl)
          Class.new(ActiveRecord::Base) do
            set_table_name tbl
          end
        end
        def drop_index_tables(target_tables=nil)
          klass = self
          dest = klass.connection
          target_tables = (CONFIG[klass.table_name] || {}).values & dest.tables
          target_tables.each {|tbl|
            sql = "DROP TABLE %s" % dest.quote_table_name(tbl)
            dest.execute(sql)
          }
        end
        def create_index_table!(tbl, cols, primary_key = self.primary_key, defined_columns = self.defined_columns, data_table = self.table_name)
          self.connection.instance_eval do
            create_table(tbl, :force => false, :primary_key => 'guid', :options=>"ENGINE=MyISAM") do |t|
              (cols - [primary_key]).uniq.each do |c|
                if args = defined_columns[data_table][c]
                  t.send(:column, *args)
                end
              end
              t.timestamps
            end
            change_column tbl, :guid, :string
            add_index tbl, cols, :name => "main"
          end
        end
        def create_missing_index_tables
          created_count = 0
          tables = self.connection.tables
          (CONFIG[self.table_name] || {}).each do |cols, tbl|
            next if tables.include?(tbl)
            created_count += 1
            create_index_table!(tbl, cols)
          end
          queue_populate_index_job if created_count > 0
        end
        def queue_populate_index_job(page=1, per_page=500)
          return if ENV['SKIP_POPULATE_INDEX_JOB']
          config = CONFIG[table_name] || {}
          tables = connection.tables
          config.each do |dest_cols, dest_tbl|
            next unless tables.include?(dest_tbl)
            Delayed::Job.enqueue ActiverecordDIY::Index::Model::Job.new(self.table_name, page, per_page, dest_tbl, ["guid"] + dest_cols)
          end
        end
      end
      class Job < Struct.new(:source_tbl, :page, :per_page, :dest_tbl, :dest_cols)
        def perform
          counted = 0
          offset = (page-1)*per_page
          conn = ActiveRecord::Base.connection
          conn.execute("SELECT guid,json,created_at,updated_at FROM #{conn.quote_table_name(source_tbl)} ORDER BY created_at DESC LIMIT #{offset},#{per_page}").each do |guid,json,created_at,updated_at|
            hash = JSON.parse(json).merge({
              "guid" => guid,
              "created_at" => created_at,
              "updated_at" => updated_at,
            })
            statement = "REPLACE INTO %s (%s) VALUES (%s)" % [
              conn.quote_table_name(dest_tbl),
              dest_cols.collect {|n| conn.quote_column_name(n) }.join(','),
              dest_cols.collect {|n| conn.quote(hash[n]) }.join(','),
            ]
            conn.execute(statement)
            counted += 1
          end
          Delayed::Job.enqueue self.class.new(source_tbl, page+1, per_page, dest_tbl, dest_cols) if counted == per_page
        end
      end
      module InstanceMethods
        def update_indexes(table_columns = nil)
          klass = self.class
          table_columns ||= CONFIG[klass.table_name] || {}
          table_columns.each do |index_column_names, dest_tbl|
            dest_cols = ([klass.primary_key, "created_at", "updated_at"] + index_column_names).collect(&:to_s).uniq
            statement = "REPLACE INTO %s (%s) VALUES (%s)" % [
              connection.quote_table_name(dest_tbl),
              dest_cols.collect {|n| connection.quote_column_name(n) }.join(','),
              dest_cols.collect {|n| connection.quote(self.send(n)) }.join(','),
            ]
            connection.execute(statement)
          end
        end
      end
    end
  end
end
