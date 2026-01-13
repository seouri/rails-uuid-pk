require_relative "lib/rails_uuid_pk/version"

Gem::Specification.new do |spec|
  spec.name        = "rails-uuid-pk"
  spec.version     = RailsUuidPk::VERSION
  spec.authors     = [ "Joon Lee" ]
  spec.email       = [ "seouri@gmail.com" ]
  spec.homepage    = "https://github.com/seouri/rails-uuid-pk"
  spec.summary     = "Dead-simple UUID v7 primary keys for Rails apps"
  spec.description = "Automatically use UUID v7 for all primary keys in Rails applications. Works with PostgreSQL, MySQL, and SQLite, zero configuration required."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.required_ruby_version = ">= 3.3.0"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "rails", "~> 8.0"
  spec.add_development_dependency "mysql2", "~> 0.5.7"
  spec.add_development_dependency "pg", "~> 1.6.3"
  spec.add_development_dependency "sqlite3", "~> 2.9.0"
  spec.add_development_dependency "yard", "~> 0.9"
end
