require_relative "lib/recordables/version"

Gem::Specification.new do |spec|
  spec.name        = "recordables"
  spec.version     = Recordables::VERSION
  spec.authors     = ["Jonas Medeiros"]
  spec.email       = ["jonas.g.medeiros@gmail.com"]
  spec.summary     = "Generators and runtime helpers for versioned delegated types."
  spec.description = "Scaffolds a recordings/recordables/events content spine into a Rails app, " \
                     "and keeps the snapshot copy-forward logic that is easy to get silently wrong."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.homepage = "https://github.com/jonasmedeiros/recordables"
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1", "< 9"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
