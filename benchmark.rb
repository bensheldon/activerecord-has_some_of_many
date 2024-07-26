# frozen_string_literal: true

require_relative "test_helper"

Post.delete_all
Comment.delete_all

class TestPost < Post
  has_one_of_many :last_comment, -> { order(created_at: :desc) }, class_name: 'Comment', foreign_key: "post_id"
  has_many :omg_comments, -> { ActiveRecord::Relation.create(Comment, table: Comment.arel_table.alias("omg_comments")).from(arel_table.as("omg_comments")).order(:created_at) }, class_name: "Comment", foreign_key: "post_id"
end

Post.transaction do
  1000.times.map do
    post = TestPost.create
    10.times do |index|
      post.comments.create!(body: "Comment #{index + 1}")
    end
  end
end

existing_relation = Comment.where(post: Post.first).limit(2)
aliased_relation = ActiveRecord::Relation.create(Comment, table: Comment.arel_table.alias("omg_comments"))

binding.irb

