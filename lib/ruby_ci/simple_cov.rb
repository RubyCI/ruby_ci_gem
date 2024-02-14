require_relative "simple_cov/reporting"

module RubyCI
  module SimpleCov
    ::SimpleCov.send(:include, RubyCI::SimpleCov::Reporting)
  end
end