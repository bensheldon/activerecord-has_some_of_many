require 'active_support/lazy_load_hooks'
require_relative "active_record/has_some_of_many/version"

ActiveSupport.on_load(:active_record) do
  require_relative "active_record/has_some_of_many/associations"
  include ActiveRecord::HasSomeOfMany::Associations
end
