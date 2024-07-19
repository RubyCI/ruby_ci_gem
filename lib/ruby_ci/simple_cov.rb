require_relative "simple_cov/reporting"

module RubyCI
  module SimpleCov
    ::SimpleCov.send(:include, RubyCI::SimpleCov::Reporting) unless ENV['DRYRUN'] == 'true'
  end
end