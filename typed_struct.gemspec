# frozen_string_literal: true

require_relative "lib/typed_struct/version"

Gem::Specification.new do |spec|
  spec.name          = "typed_struct"
  spec.version       = TypedStruct::VERSION
  spec.authors       = ["Joseph Johansen"]
  spec.email         = ["joe@stotles.com"]

  spec.summary       = "Lightweight and flexible typed structs"
  spec.description   = "All the flexibility of a Ruby Struct, but with type checking on its properties. Also benefit from being able to define complex types using RBS type notation."
  spec.homepage      = "https://github.com/johansenja/typed_struct"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "rbs", "~> 1.0"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
