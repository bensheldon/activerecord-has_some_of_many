# frozen_string_literal: true

require "test_helper"

class ActiveRecordHasSomeOfManyTest < ActiveSupport::TestCase
  include ActiveRecord::Assertions::QueryAssertions

  def setup
    Post.delete_all
    Comment.delete_all
    Leaf.delete_all
  end

  def strip(sql)
    sql.squish.gsub(/\s+/, " ").gsub(" ( ", " (").gsub(" ) ", ") ")
  end

  test "it has a version number" do
    assert ActiveRecord::HasSomeOfMany::VERSION
  end

  class TestHasOneOfManyPost < Post
    has_one_of_many :last_comment, -> { order(created_at: :desc) }, class_name: 'Comment', foreign_key: "post_id"
  end

  class TestHasSomeOfManyPost < Post
    has_some_of_many :last_two_comments, -> { order(created_at: :desc).limit(2) }, class_name: 'Comment', foreign_key: "post_id"
  end

  class TestHasSomeOfManyLeaf < Leaf
    has_one_of_many :last_child, -> { order(created_at: :desc) }, class_name: 'Leaf', foreign_key: "parent_id"
    has_some_of_many :last_two_children, -> { order(created_at: :desc).limit(2) }, class_name: 'Leaf', foreign_key: "parent_id"
  end

  test "#has_one_of_many" do
    5.times do
      post = TestHasOneOfManyPost.create!
      10.times do |index|
        post.comments.create!(body: "Comment #{index + 1}")
      end
    end

    assert_equal "Comment 10", TestHasOneOfManyPost.first.last_comment.body

    assert_queries_count(2) do
      TestHasOneOfManyPost.preload(:last_comment).each do |post|
        assert_equal "Comment 10", post.last_comment.body
      end
    end

    expected_query = strip(<<~SQL)
      SELECT "comments".*
      FROM (
        SELECT "posts"."id" AS post_id_alias, "lateral_table".*
        FROM "posts"
        INNER JOIN LATERAL (
          SELECT "comments".*
          FROM "comments"
          WHERE "comments"."post_id" = "posts"."id"
          ORDER BY "comments"."created_at" DESC
          LIMIT $1
        ) lateral_table ON TRUE
      ) comments
      WHERE "comments"."post_id_alias" IN ($2, $3, $4, $5, $6)
    SQL

    assert_queries_match(expected_query) do
      TestHasOneOfManyPost.preload(:last_comment).load
    end
  end

  test "#has_some_of_many" do
    5.times do
      post = TestHasSomeOfManyPost.create!
      10.times do |index|
        post.comments.create!(body: "Comment #{index + 1}")
      end
    end

    assert_equal ["Comment 10", "Comment 9"], TestHasSomeOfManyPost.first.last_two_comments.map(&:body)

    assert_queries_count(2) do
      TestHasSomeOfManyPost.preload(:last_two_comments).each do |post|
        assert_equal ["Comment 10", "Comment 9"], post.last_two_comments.map(&:body)
      end
    end
    expected_query = strip(<<~SQL)
      SELECT "comments".*
      FROM (
        SELECT "posts"."id" AS post_id_alias, "lateral_table".*
        FROM "posts"
        INNER JOIN LATERAL (
          SELECT "comments".*
          FROM "comments"
          WHERE "comments"."post_id" = "posts"."id"
          ORDER BY "comments"."created_at" DESC
          LIMIT $1
        ) lateral_table ON TRUE
      ) comments
      WHERE "comments"."post_id_alias" IN ($2, $3, $4, $5, $6)
    SQL

    assert_queries_match(expected_query) do
      TestHasSomeOfManyPost.preload(:last_two_comments).load
    end
  end

  test "self-referential relations" do
    5.times do
      leaf = TestHasSomeOfManyLeaf.create!
      10.times do |index|
        leaf.children.create!(name: "Child #{index + 1}")
      end
    end

    assert_equal ["Child 10", "Child 9"], TestHasSomeOfManyLeaf.where(parent_id: nil).first.last_two_children.map(&:name)

    assert_queries_count(2) do
      TestHasSomeOfManyLeaf.where(parent_id: nil).preload(:last_two_children).each do |leaf|
        assert_equal ["Child 10", "Child 9"], leaf.last_two_children.map(&:name)
      end
    end
    expected_query = strip(<<~SQL)
      SELECT "leafs".*
      FROM (
        SELECT "leafs"."id" AS parent_id_alias, "lateral_table".*
        FROM "leafs"
        INNER JOIN LATERAL (
          SELECT "leafs__alias".*
          FROM "leafs" "leafs__alias"
          WHERE "leafs__alias"."parent_id" = "leafs"."id"
          ORDER BY "leafs__alias"."created_at" DESC
          LIMIT $1
        ) lateral_table ON TRUE
      ) leafs
      WHERE "leafs"."parent_id_alias" IN ($2, $3, $4, $5, $6)
    SQL

    assert_queries_match(expected_query) do
      TestHasSomeOfManyLeaf.where(parent_id: nil).preload(:last_two_children).load
    end
  end

  class CommentWithIgnoredColumns < Comment
    self.ignored_columns = %w[created_at updated_at]
  end

  class PostHasCommentsWithIgnoredColumns < Post
    has_some_of_many :last_two_comments, -> { order(created_at: :desc).limit(2) }, class_name: 'CommentWithIgnoredColumns', foreign_key: "post_id"
  end

  test "Model with ignored columns" do
    post = PostHasCommentsWithIgnoredColumns.create!
    10.times do |index|
      post.comments.create!(body: "Comment #{index + 1}")
    end

    relation = ActiveRecord::HasSomeOfMany::Associations.build_scope(PostHasCommentsWithIgnoredColumns, CommentWithIgnoredColumns.order(id: :desc), primary_key: "id", foreign_key: "post_id", foreign_key_alias: "post_id_alias", limit: 1)
    assert_equal relation.to_sql, strip(<<~SQL)
      SELECT "comments"."post_id_alias", "comments"."id", "comments"."body", "comments"."post_id"
      FROM (
        SELECT "posts"."id" AS post_id_alias, "lateral_table".*
        FROM "posts"
        INNER JOIN LATERAL (
          SELECT "comments"."id", "comments"."body", "comments"."post_id"
          FROM "comments"
          WHERE "comments"."post_id" = "posts"."id"
          ORDER BY "comments"."id" DESC
          LIMIT 1
        ) lateral_table ON TRUE
      ) comments
    SQL

    PostHasCommentsWithIgnoredColumns.includes(:last_two_comments).each do |post|
      assert_equal ["Comment 10", "Comment 9"], post.last_two_comments.map(&:body)
    end
  end

  test ".build_scope" do
    relation = ActiveRecord::HasSomeOfMany::Associations.build_scope(Post, Comment.order(id: :desc), primary_key: "id", foreign_key: "post_id", foreign_key_alias: "post_id_alias", limit: 1)

    assert_equal relation.to_sql, strip(<<~SQL)
      SELECT "comments".* FROM (
        SELECT "posts"."id" AS post_id_alias, "lateral_table".*
        FROM "posts"
        INNER JOIN LATERAL (
          SELECT "comments".*
          FROM "comments"
          WHERE "comments"."post_id" = "posts"."id"
          ORDER BY "comments"."id" DESC
          LIMIT 1
        ) lateral_table ON TRUE
      ) comments
    SQL
  end

  test "Active Record batches does not rescope subselect query" do
    10.times do |post_index|
      post = TestHasSomeOfManyPost.create! title: "Post #{post_index + 1}"
      10.times do |comment_index|
        post.comments.create!(body: "#{post.title} Comment #{comment_index + 1}")
      end
    end

    expected_query = strip(<<~SQL)
      SELECT "comments".*
      FROM (
        SELECT "posts"."id" AS post_id_alias, "lateral_table".*
        FROM "posts"
        INNER JOIN LATERAL (
          SELECT "comments".*
          FROM "comments"
          WHERE "comments"."post_id" = "posts"."id"
          ORDER BY "comments"."created_at" DESC
          LIMIT $1
        ) lateral_table ON TRUE
      ) comments
      WHERE "comments"."post_id_alias" IN ($2, $3, $4, $5, $6)
    SQL

    assert_queries_match(expected_query, count: 2) do
      TestHasSomeOfManyPost.where.not(title: nil).includes(:last_two_comments).find_in_batches(batch_size: 5) do |batch_array|
        batch_array.each do |post|
          assert_equal ["#{post.title} Comment 10", "#{post.title} Comment 9"], post.last_two_comments.map(&:body)
        end
      end
    end

    assert_queries_match(expected_query, count: 2) do
      TestHasSomeOfManyPost.in_batches(of: 5) do |batch_relation|
        batch_relation.includes(:last_two_comments).each do |post|
          assert_equal ["#{post.title} Comment 10", "#{post.title} Comment 9"], post.last_two_comments.map(&:body)
        end
      end
    end
  end
end
