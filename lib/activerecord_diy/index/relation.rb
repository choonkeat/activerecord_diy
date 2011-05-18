# encoding: utf-8
module ActiverecordDIY
  module Index
    module Relation
      extend ActiveSupport::Concern
      included do
        alias_method_chain :to_a, :index
        alias_method_chain :to_sql, :index
      end
      module InstanceMethods
        def swap_arel_attr_relation_table_with(attrs, orig_table, dest_table)
          # hacky, but works..
          attrs.collect do |attribute|
            [:left, :right].each do |side|
              if attribute.respond_to?(side) && attribute.send(side).respond_to?(:relation) && attribute.send(side).relation == orig_table
                attribute = attribute.clone
                attribute.send("#{side}=", attribute.send(side).clone)
                attribute.send(side).relation = dest_table
              end
            end
            attribute
          end
        end
        def index_table_name
          @names = ([@klass.table_name] + index_column_names)
          name = @names.reject(&:blank?).join('_')
          return name unless name.length > 64
          @names.collect {|n| n.gsub(/[aeiou]/i, '') }.reject(&:blank?).join('_')
        end
        def index_column_names
          cols = (@implied_columns||[]) +
            [:where_values, :having_values].collect {|meth| self.send(meth).collect {|w| w.respond_to?(:left) ? [w.left, w.right].select {|n| n.kind_of?(Arel::Attributes::Attribute) }.collect(&:name) : w } } +
            order_values.collect {|n| n.gsub(/\s+(asc|desc)$/i, '') }
          cols.flatten.collect do |s|
            case s
            when Symbol
              s.to_s
            when /\A(.+\.|)([\`\w]+)/
              $2.to_s.gsub(/\W+/, '')
            end
          end.uniq.compact.sort
        end
        def with_implied_columns(cols)
          @implied_columns = cols
          yield self
        ensure
          @implied_columns = []
        end
        def with_table(new_tbl)
          old_tbl = self.table.name
          self.table.name = new_tbl
          yield self.clone
        ensure
          self.table.name = old_tbl
        end
        def klass_uses_index?
          @klass.ancestors.include?(ActiverecordDIY::Index::Model)
        end
        def not_using_index?
          result = begin
            (!klass_uses_index?) ||
            (index_column_names == [@klass.primary_key])
          end
          result
        end
        def copy_relation_from_to(from, other)
          other.select_values = from && swap_arel_attr_relation_table_with(from.select_values.try(:dup), from.table, other.table) || []
          other.where_values  = from && swap_arel_attr_relation_table_with(from.where_values.try(:dup), from.table, other.table)  || []
          other.having_values = from && swap_arel_attr_relation_table_with(from.having_values.try(:dup), from.table, other.table) || []
          other.order_values  = from && swap_arel_attr_relation_table_with(from.order_values.try(:dup), from.table, other.table)  || []
          other.limit_value   = from && from.limit_value  || nil
          other.offset_value  = from && from.offset_value || nil
          other
        end
        def to_sql_with_index
          return self.to_sql_without_index if not_using_index?
          case self.select_values.first
          when Arel::Nodes::Function
            with_implied_columns(self.select_values.collect {|n| n.expressions }.reject {|n| n == '*' || n.blank? }) do |rel|
              other = copy_relation_from_to(rel, @klass.index_table_wrapper_class(rel.index_table_name).unscoped.clone)
              other.to_sql_without_index
            end
          else
            self.to_sql_with_guids( self.to_guids, keep_select = true)
          end
        end
        def to_sql_with_guids(guids, keep_select = true)
          other = copy_relation_from_to(nil, self.clone)
          other.select_values = self.select_values.dup if keep_select
          other.where(@klass.primary_key => guids).to_sql_without_index
        end
        def to_guids
          with_table(self.index_table_name) do |rel|
            rel.select_values = [@klass.primary_key]
            sql = rel.to_sql_without_index
            rel.engine.connection.execute(sql).collect {|row| row.first}
          end
        end
        def to_a_with_index
          return self.to_a_without_index if not_using_index?
          guids = self.to_guids
          objects = @klass.find_by_sql( self.to_sql_with_guids(guids, keep_select = false) )
          guids.collect {|id| objects.find {|o| o.id == id }}
        end
      end
      module ClassMethods
        #
      end
    end
  end
end

require 'active_support/core_ext/module/delegation'
require 'active_record'
ActiveRecord::Relation.send(:include, ActiverecordDIY::Index::Relation)
