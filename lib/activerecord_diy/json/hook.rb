# encoding: utf-8
module ActiverecordDIY
  module Json
    module Hook
      extend ActiveSupport::Concern
      module ClassMethods
        def use_json_attributes
          include ActiverecordDIY::Json::Backed
          yield self if block_given?
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiverecordDIY::Json::Hook
