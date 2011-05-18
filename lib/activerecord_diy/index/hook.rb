# encoding: utf-8
module ActiverecordDIY
  module Index
    module Hook
      extend ActiveSupport::Concern
      module ClassMethods
        def use_index_tables
          include ActiverecordDIY::Index::Model
          CONFIG[self.table_name] = {}
          yield self if block_given?
          create_missing_index_tables
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiverecordDIY::Index::Hook
