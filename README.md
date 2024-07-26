# `activerecord-has_some_of_many`

Adds optimized Active Record association methods for "top N" queries to ActiveRecord using `JOIN LATERAL` that are eager-loadable to avoid N+1 queries. For example:

- Finding the most recent post each for a collection of users
- Finding the top ranked comment each for a collection of users

You can read more about these types of queries on [Benito Serna's "Fetching the top n per group with a lateral join with rails"](https://bhserna.com/fetching-the-top-n-per-group-with-a-lateral-join-with-rails.html).

## Usage

Add to your gemfile, and run `bundle install`:

```ruby
  gem "activerecord-has_some_of_many"
```

Then you can use `has_one_of_many` and `has_some_of_many` in your ActiveRecord models to define these associations.

```ruby
class User < ActiveRecord::Base
  has_one_of_many :last_post, -> { order("created_at DESC") }, class_name: "Post"

  # You can also use `has_some_of_many` to get the top N records. Be sure to add a limit to the scope.
  has_some_of_many :last_five_posts, -> { order("created_at DESC").limit(5) }, class_name: "Post"

  # More complex scopees are possible, for example:
  has_one_of_many :top_comment, -> { where(published: true).order("votes_count DESC") }, class_name: "Comment"
  has_some_of_many :top_ten_comments, -> { where(published: true).order("votes_count DESC").limit(10) }, class_name: "Comment"
end

# And then preload/includes and use them like any other Rails association:
User.where(active: true).includes(:last_post, :last_five_posts, :top_comment).each do |user|
  user.last_post
  user.last_five_posts
  user.top_comment
end
```

## Development

- Run the tests with `bundle exec rake`
