require_relative "lib/activerecord/has_some_of_many/version"

Gem::Specification.new do |spec|
  spec.name        = "activerecord-has_some_of_many"
  spec.version     = ActiveRecord::HasSomeOfMany::VERSION
  spec.authors     = ["Ben Sheldon [he/him]"]
  spec.email       = ["bensheldon@gmail.com"]
  spec.homepage    = "https://github.com/bensheldon/activerecord-has_some_of_many"
  spec.summary     = "An Active Record extension for creating associations through lateral joins"
  spec.description = "An Active Record extension for creating associations through lateral joins"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] =  "https://github.com/bensheldon/activerecord-has_some_of_many"
  spec.metadata["changelog_uri"] =  "https://github.com/bensheldon/activerecord-has_some_of_many"

  spec.files = Dir[
    "lib/**/*",
    "README.md",
    "LICENSE.txt",
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0.0.alpha"
  spec.add_dependency "railties", ">= 7.0.0.alpha"
end

