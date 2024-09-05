# frozen_string_literal: true

require_relative "lib/ruby_ci/version"

Gem::Specification.new do |spec|
  spec.name          = "ruby_ci"
  spec.version       = RubyCI::VERSION
  spec.authors       = ["Nesha Zoric"]
  spec.email         = ["no-reply@ruby.ci"]

  spec.summary       = "Ruby wrapper for creating RubyCI integrations"
  spec.description   = "Ruby wrapper for creating RubyCI integrations"
  spec.homepage      = "https://github.com/RubyCI/ruby_ci_gem"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.executables   = ["rubyci_rubycritic", "rubyci_brakeman"]
  spec.require_paths = ["lib"]

  spec.add_dependency "console", "~> 1.26.0"
  spec.add_dependency "async-websocket", '<= 0.20.0'
  spec.add_dependency "rubycritic", ">= 4.1.0"
  spec.add_dependency "brakeman", ">= 5.4.1"
  spec.add_dependency "async-pool", "= 0.4.0"
  spec.add_dependency "fiber-local", "= 1.0.0"
  spec.add_dependency "minitest-rails", ">= 5.1"
  spec.add_development_dependency "pry"
end
