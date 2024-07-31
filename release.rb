#!/usr/bin/env ruby
# frozen_string_literal: true

begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require "active_support/inflector"

GITHUB_USER = "bensheldon"
PROJECT_NAME = "activerecord-has_some_of_many"
VERSION_CLASS = "ActiveRecord::HasSomeOfMany::VERSION"
VERSION_FILE_PATH = "lib/activerecord/has_some_of_many/version.rb"

require_relative VERSION_FILE_PATH
require 'dotenv/load'

require 'optparse'
args = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-versionVERSION", "--version=VERSION", "Version to bump") do |value|
    args[:version_bump] = value
  end
end.parse!

def system!(*args)
  system(*args) || abort("\n== Command #{args} failed ==")
end

version_bump = args[:version_bump]
if version_bump.nil?
  puts "Pass a version [major|minor|patch|pre|release] or a given version number [x.x.x]:"
  puts "$ bundle exec release.rb --version [VERSION_BUMP]"
  exit(1)
end

puts "\n== Bumping version number =="
system! "gem bump --no-commit --version #{version_bump}"

puts "\n== Reloading #{VERSION_CLASS}"
load File.expand_path(VERSION_FILE_PATH, __dir__)
VERSION = ActiveSupport::Inflector.constantize(VERSION_CLASS)

puts "\n== Updating Changelog =="
system! ENV, "bundle exec github_changelog_generator --user #{GITHUB_USER} --project #{PROJECT_NAME} --future-release v#{VERSION} --cache-file=tmp/github-changelog-http-cache"

puts "\n== Updating Gemfile.lock version =="
system! "bundle update --conservative #{PROJECT_NAME}"

# puts "\n== Verifying Gemfile.lock =="
# gemfile_lock = File.read(File.join(File.dirname(__FILE__), 'Gemfile.lock'))
#
puts "\n== Creating gem package and sha512 checksum =="
system! "bundle exec rake build:checksum"

puts "\n== Creating sha256 checksum too =="
require "digest/sha2"
gem_filename = "#{PROJECT_NAME}-#{VERSION}.gem"
sha256_checksum = Digest::SHA256.hexdigest File.read "#{__dir__}/pkg/#{gem_filename}"
File.write "#{__dir__}/checksums/#{gem_filename}.sha256", "#{sha256_checksum}\n"

puts "\n== Creating git commit  =="
system! "git add #{VERSION_FILE_PATH} CHANGELOG.md Gemfile.lock checksums"
system! "git commit -m \"Release #{PROJECT_NAME} v#{VERSION}\""
system! "git tag v#{VERSION}"

require 'cgi'
changelog_anchor = "v#{VERSION.delete('.')}-#{Time.now.utc.strftime('%Y-%m-%d')}"
changelog_url = "https://github.com/bensheldon/activerecord-has_some_of_many/blob/main/CHANGELOG.md##{changelog_anchor}"

puts "\n"
puts <<~INSTRUCTIONS
    == Next steps ==

    Run the following commands:

    1. Push commit and tag to Github:
        git push origin && git push origin --tags
    2. Push to Rubygems.org:
        gem push pkg/#{PROJECT_NAME}-#{VERSION}.gem
    3. Author a Github Release:
        https://github.com/bensheldon/activerecord-has_some_of_many/releases/new?tag=v#{VERSION}&body=#{CGI.escape "_Review the [Changelog](#{changelog_url}) for more details._"}
  INSTRUCTIONS
