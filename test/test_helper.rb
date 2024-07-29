require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/spec'
require 'active_record'
require 'activerecord-has_some_of_many'

require_relative "support/active_record_query_assertions"

DB_CONFIG = if ENV.fetch("DATABASE", "postgresql") == "postgresql"
              {
                adapter: "postgresql",
                database: "has_some_of_many_test",
                host: "localhost",
              }
            else
              {
                adapter: "sqlite3",
                database: "tmp/lateral_associations_test.sqlite3",
              }
            end

begin
  log_file = File.open(File.expand_path("../tmp/test.log", __dir__), "a").tap do |f|
    f.binmode
    f.sync = true
  end
  ActiveRecord::Base.logger = ActiveSupport::Logger.new(log_file)
  ActiveRecord::Base.establish_connection(DB_CONFIG)

  ActiveRecord::Schema.verbose = false
  ActiveRecord::Schema.define do
    create_table :posts, force: true do |t|
      t.timestamps
      t.string :title
    end

    create_table :comments, force: true do |t|
      t.timestamps
      t.string :body
      t.references :post, index: false
      t.index [:post_id, :created_at]
    end
  end
rescue ActiveRecord::NoDatabaseError
  raise if retried ||= nil

  ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: "postgres", schema_search_path: "public"))
  ActiveRecord::Base.connection.create_database(DB_CONFIG[:database])
  ActiveRecord::Base.remove_connection

  retried = true
  retry
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end
