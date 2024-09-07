# frozen_string_literal: true

module ActiveRecord
  module HasSomeOfMany
    class RelationRewriter
      def initialize(relation)
        @relation = relation
      end

      def alias_table(alias_name)
        relation_class = @relation.klass
        original_table = relation_class.arel_table
        alias_table = original_table.alias(alias_name)

        where_clause = recursively_alias_table(@relation.where_clause.ast, original_table, alias_table)
        order_clause = @relation.order_values.map do |order|
          if order.respond_to?(:expr)
            order.expr = alias_table[order.expr.name] if order.expr.relation == original_table
          end
          order
        end

        new_relation = @relation.dup.unscope(:select, :where, :order)
        new_relation.instance_variable_set(:@table, alias_table) # Is there a better way to modify the original relation?
        new_relation.where(where_clause).order(order_clause)
      end

      def recursively_alias_table(node, original_table, alias_table)
        case node
        when Arel::Nodes::And, Arel::Nodes::Or
          return nil if node.children.empty?

          # Recurse for left and right nodes
          node.children.each { |child| recursively_alias_table(child, original_table, alias_table) }
          node
        when Arel::Nodes::Grouping
          # Recurse for the expression inside the grouping
          node.expr = recursively_alias_table(node.expr, original_table, alias_table)
          node
        when Arel::Nodes::Equality, Arel::Nodes::GreaterThan, Arel::Nodes::LessThan, Arel::Nodes::HomogeneousIn
          # For conditions, modify left-hand side (the column)
          if node.left.relation == original_table
            node.left.relation = alias_table
          end
          node
        else
          node
        end
      end
    end
  end
end
