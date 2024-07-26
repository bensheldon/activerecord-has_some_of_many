# frozen_string_literal: true

module ActiveRecord
  module HasSomeOfMany
    module Associations
      extend ActiveSupport::Concern

      # @param [ActiveRecord::Base] klass The primary class
      # @param [Symbol] association_type For example, `:has_one` or `:has_many`
      # @param [Symbol] name The name of the association
      # @param [Proc, nil] scope A scope to apply to the association
      # @param [Hash] options Additional options to pass to the association
      def self.build(klass, association_type, name, scope = nil, **options)
        primary_key = options[:primary_key] || klass.primary_key
        foreign_key = options[:foreign_key] || ActiveSupport::Inflector.foreign_key(klass, true)
        foreign_key_alias = options[:foreign_key_alias] || "#{foreign_key}_alias"

        lateral_subselection_scope = lambda do
          relation = scope ? instance_exec(&scope) : self
          limit = association_type == :has_one ? 1 : nil
          ActiveRecord::HasSomeOfMany::Associations.build_scope(klass, relation, primary_key: primary_key, foreign_key: foreign_key, foreign_key_alias: foreign_key_alias, limit: limit)
        end

        options[:primary_key] = primary_key
        options[:foreign_key] = foreign_key_alias

        klass.send(association_type, name, lateral_subselection_scope, **options)
      end

      def self.build_scope(klass, relation, primary_key:, foreign_key:, foreign_key_alias:, limit: nil)
        lateral_table = Arel::Table.new('lateral_table')
        subselect = klass.unscope(:select)
                      .select(klass.arel_table[primary_key].as(foreign_key_alias), lateral_table[Arel.star])
                      .arel.join(
                        relation
                          .where(relation.arel_table[foreign_key].eq(klass.arel_table[primary_key]))
                          .then { |query| limit ? query.limit(limit) : query }
                          .arel.lateral(lateral_table.name)
                      ).on("TRUE")

        relation.klass.from(subselect.as(relation.arel_table.name))
      end

      class_methods do
        # Fetch the first record of a has_one-like association using a lateral join
        #
        # @example Given posts have many comments; query the most recent comment on a post
        #   class Post < ApplicationRecord
        #     one_of_many :last_comment, -> { order(created_at: :desc) }, class_name: 'Comment'
        #   end
        #
        #   Post.published.includes(:last_comment).each do |post
        #     posts.last_comment # => #<Comment>
        #   end
        def has_one_of_many(name, scope = nil, **options)
          ActiveRecord::HasSomeOfMany::Associations.build(self, :has_one, name, scope, **options)
        end

        # Fetch a limited number of records of a has_many-like association using a lateral join
        #
        # @example The 10 most recent comments on a post
        #   class Post < ApplicationRecord
        #     has_some_of_many :last_ten_comments, -> { order(created_at: :desc).limit(10) }, class_name: 'Comment'
        #   end
        #
        #   Post.published.includes(:last_ten_comments).each do |post
        #     posts.last_ten_comments # => [#<Comment>, #<Comment>, ...]
        #   end
        def has_some_of_many(name, scope = nil, **options)
          ActiveRecord::HasSomeOfMany::Associations.build(self, :has_many, name, scope, **options)
        end
      end
    end
  end
end
