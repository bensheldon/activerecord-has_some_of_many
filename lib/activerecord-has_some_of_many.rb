# frozen_string_literal: true

require 'active_support/lazy_load_hooks'
require_relative "activerecord/has_some_of_many/version"

ActiveSupport.on_load(:active_record) do
  require_relative "activerecord/has_some_of_many/associations"
  include ActiveRecord::HasSomeOfMany::Associations
end
