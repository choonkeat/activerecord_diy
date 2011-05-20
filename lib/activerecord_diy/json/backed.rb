# encoding: utf-8
require 'uuid'

module ActiverecordDIY
  module Json
    module Backed
      UUID_GENERATOR = UUID.new
      extend ActiveSupport::Concern
      included do
        set_primary_key :guid
        before_create :set_guid
        before_save :update_json
        create_json_backed_table_if_missing
      end
      module ClassMethods
        def drop_json_backed_table
          self.drop_index_tables if self.respond_to?(:drop_index_tables)
          tbl = self.table_name
          connection.drop_table(tbl) if connection.tables.include?(tbl)
        end
        def create_json_backed_table_if_missing
          tbl = self.table_name
          connection.instance_eval do
            create_table(tbl, :primary_key => 'guid', :options=>"ENGINE=MyISAM") do |t|
              t.binary :json
              t.timestamps
            end
            change_column tbl, :guid, :string
            add_index tbl, :created_at
          end unless connection.tables.include?(tbl)
        end
        def defined_columns
          @defined_columns ||= {self.table_name => {}}
        end
        def column(col, *options)
          column_type = options.first
          @defined_columns ||= {self.table_name => {}}
          @defined_columns[self.table_name].merge!(col.to_s => [col] + options)
          self.instance_eval do
            define_method(col) do
              value = json_object[col.to_s]
              return value if !value.kind_of?(String) || column_type == 'string'
              case column_type
              when 'datetime'
                Time.parse(value)
              when 'integer'
                value.to_i
              when 'float'
                value.to_f
              else
                value
              end
            end
            define_method("#{col}=") do |val|; json_object[col.to_s]=val; end
          end
        end
        # from active_record/connection_adapters/abstract/schema_definitions
        %w( string text integer float decimal datetime timestamp time date binary boolean ).each do |column_type|
          class_eval <<-EOV, __FILE__, __LINE__ + 1
            def #{column_type}(*args)                                               # def string(*args)
              options = args.extract_options!                                       #   options = args.extract_options!
              column_names = args                                                   #   column_names = args
                                                                                    #
              column_names.each { |name| column(name, '#{column_type}', options) }  #   column_names.each { |name| column(name, 'string', options) }
            end                                                                     # end
          EOV
        end
      end
      module InstanceMethods
        def set_guid
          self.guid = UUID_GENERATOR.generate unless self.guid
        end
        def json_object
          @json_object ||= (self.json && JSON.parse(self.json)) || {}
        end
        def update_json
          self.json = @json_object.to_json if @json_object
        end
      end
    end
  end
end