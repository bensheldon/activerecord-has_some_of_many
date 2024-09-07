# frozen_string_literal: true

require "test_helper"

class RelationRewriterTest < ActiveSupport::TestCase
  include ActiveRecord::Assertions::QueryAssertions
  include SQLTestHelpers

  def setup
    Leaf.delete_all
  end

  test "#alias_table" do
    relation = Leaf.where(id: [1, 2]).or(Leaf.where(published: true)).order(created_at: :desc)
    new_relation = ActiveRecord::HasSomeOfMany::RelationRewriter.new(relation).alias_table("omg_leafs")

    assert_equal "omg_leafs", new_relation.table.name
    assert_sql(<<~SQL, new_relation.to_sql)
      SELECT "omg_leafs".*
      FROM "leafs" "omg_leafs"
      WHERE ("omg_leafs"."id" IN (1, 2) OR "omg_leafs"."published" = TRUE)
      ORDER BY "omg_leafs"."created_at" DESC
    SQL
  end

  test "#alias_table without where clause" do

    relation = Leaf.order(created_at: :desc).limit(2)
    new_relation = ActiveRecord::HasSomeOfMany::RelationRewriter.new(relation).alias_table("omg_leafs")

    assert_sql(<<~SQL, new_relation.to_sql)
      SELECT "omg_leafs".*
      FROM "leafs" "omg_leafs"
      ORDER BY "omg_leafs"."created_at" DESC
      LIMIT 2
    SQL
  end
end


