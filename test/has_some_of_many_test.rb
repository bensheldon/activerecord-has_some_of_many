require "test_helper"

class ActiveRecordHasSomeOfManyTest < ActiveSupport::TestCase
  include ActiveRecord::Assertions::QueryAssertions

  def setup
    Post.delete_all
    Comment.delete_all
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
end
