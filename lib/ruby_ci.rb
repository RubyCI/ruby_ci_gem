# frozen_string_literal: true

require_relative "ruby_ci/version"
require_relative "ruby_ci/configuration"
require_relative "ruby_ci/exceptions"
require_relative "minitest/reporters/rubyci_reporter"

require "net/http"

module RubyCI
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= RubyCI::Configuration.new
    end

    def configure
      yield(configuration)
    end

    def report_simplecov(results)
      post_report(report_options('simplecov', results))
    end

    def report_ruby_critic(compressed_data, status)
      post_report(report_options('ruby_critic', compressed_data).merge({ status: status }))
    end

    def report_brakeman(compressed_data, status)
      post_report(report_options('brakeman', compressed_data).merge({ status: status }))
    end

    def debug(msg)
      puts "\n\e[36mDEBUG: \e[0m #{msg}\n" if ENV["RUBY_CI_DEBUG"]
    end

    def report_options(run_key, content)
      {
        build_id: RubyCI.configuration.build_id,
        run_key: run_key,
        secret_key: RubyCI.configuration.secret_key,
        branch: RubyCI.configuration.branch,
        commit: RubyCI.configuration.commit,
        commit_msg: RubyCI.configuration.commit_msg,
        author: RubyCI.configuration.author.to_json,
        content: content
      }
    end

    def post_report(data)
      uri = URI("#{RubyCI.configuration.rubyci_api_url}/api/runs")
      res = Net::HTTP.post_form(uri, data)
    end

    def send_events(data)
      reset_webmock = false
      if defined?(WebMock)
        reset_webmock = !WebMock.net_connect_allowed?
        WebMock.disable!
      end

      uri = URI("#{RubyCI.configuration.rubyci_main_url}/api/v1/gitlab_events")
      res = Net::HTTP.post_form(uri, data)

      if reset_webmock
        WebMock.enable!
      end
    end
  end
end
