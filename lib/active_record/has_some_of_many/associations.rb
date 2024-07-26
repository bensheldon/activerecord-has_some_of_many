# frozen_string_literal: true

module ActiveRecord
  module HasSomeOfMany
    module Associations
      extend ActiveSupport::Concern

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
          _has_of_many(:one, name, scope, **options)
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
          _has_of_many(:many, name, scope, **options)
        end

        # Rewrites the has_one or has_many association to use a lateral subselect.
        # The resulting SQL looks like:
        #
        #   SELECT "comments".*
        #   FROM (
        #     SELECT
        #       "posts"."id" AS post_id_alias, -- alias the foreign key to avoid ambiguous duplicate column names
        #       "lateral_table".*
        #     FROM "posts"
        #     INNER JOIN LATERAL (
        #       SELECT "comments".*
        #       FROM "comments"
        #       WHERE "comments"."post_id" = "posts"."id"
        #       ORDER BY "posts"."created_at" DESC
        #       LIMIT 10
        #     ) lateral_table ON TRUE
        #   ) comments WHERE "comments"."post_id_alias" IN (1, 2, 3, 4, 5)
        #
        def _has_of_many(type, name, scope = nil, **options)
          model_class = self
          primary_key = options[:primary_key] || self.primary_key
          foreign_key = options[:foreign_key] || ActiveSupport::Inflector.foreign_key(self, true)
          foreign_key_alias = options[:foreign_key_alias] || "#{foreign_key}_alias"

          lateral_subselection_scope = lambda do
            current_relation = scope ? instance_exec(&scope) : self

            lateral_table = Arel::Table.new('lateral_table')
            subselect = model_class.unscope(:select)
                                   .select(model_class.arel_table[primary_key].as(foreign_key_alias), lateral_table[Arel.star])
                                   .arel.join(
              current_relation
                .where(current_relation.arel_table[foreign_key].eq(model_class.arel_table[primary_key]))
                .then { |query| type == :one ? query.limit(1) : query }
                .arel.lateral(lateral_table.name)
            ).on("TRUE")

            current_relation.klass.from(subselect.as(arel_table.name))
          end

          options[:primary_key] = primary_key
          options[:foreign_key] = foreign_key_alias

          if type == :one
            has_one(name, lateral_subselection_scope, **options)
          elsif type == :many
            has_many(name, lateral_subselection_scope, **options)
          end
        end
      end
    end
  end
end
