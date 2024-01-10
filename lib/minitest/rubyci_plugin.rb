require_relative "reporters/rubyci_reporter"

module Minitest
  def self.plugin_rubyci_init(options)
    if ENV['RUBY_CI_SECRET_KEY'].present?
      Minitest.reporter << Minitest::Reporters::RubyciReporter.new
    end
  end
end
