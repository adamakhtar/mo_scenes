# frozen_string_literal: true

require_relative "lib/mo_scenes/version"

Gem::Specification.new do |spec|
  spec.name = "mo_scenes"
  spec.version = MoScenes::VERSION
  spec.authors = ["Adam Akhtar"]
  spec.summary = "Scene-based test data bootstrapping for Rails, an alternative to fixtures."
  spec.description = "MoScenes lets you define scene classes that create ActiveRecord test data once before the suite, wrapped in a transaction for fast per-test rollback. Scenes can also be used as seeds."
  spec.homepage = "https://github.com/adamakhtar/mo_scenes"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
end
