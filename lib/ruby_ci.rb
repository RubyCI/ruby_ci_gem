# frozen_string_literal: true

require_relative "ruby_ci/version"
require_relative "ruby_ci/configuration"
require_relative "ruby_ci/exceptions"

require "async"
require "async/http/endpoint"
require "async/websocket/client"
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

    def rspec_ws
      @rspec_ws ||= WebSocket.new('rspec')
    end

    def minitest_ws
      @minitest_ws ||= WebSocket.new('minitest')
    end

    def report_simplecov(results)
      uri = URI('https://fast.ruby.ci/api/runs')
      res = Net::HTTP.post_form(uri, report_options('simplecov', results))
    end

    def report_ruby_critic(compressed_data, status)
      data = report_options('ruby_critic', compressed_data)
      data[:status] = status

      uri = URI('https://fast.ruby.ci/api/runs')
      res = Net::HTTP.post_form(uri, data)
    end

    def rspec_await
      rspec_ws.await
    end

    def minitest_await
      minitest_ws.await
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
  end

  class WebSocket
    attr_reader :node_index
    attr_accessor :connection, :task, :run_key

    SUPPORTED_EVENTS = %i[enq_request deq].freeze

    def initialize(run_key)
      @on = {}
      @ref = 0
      @run_key = run_key
    end

    def on(event, &block)
      raise EventNotSupportedError, event unless SUPPORTED_EVENTS.include?(event)
      raise EventAlreadyDefinedError, event if @on[event]

      @on[event] = block
    end

    def send_msg(event, payload = {})
      RubyCI.debug("ws#send_msg: #{event} -> #{payload.inspect}")
      connection.write({ "topic": topic, "event": event, "payload": payload, "ref": ref })
      connection.flush
    end

    def connect_to_ws
      Async do |task|
        before_start_connection
        Async::WebSocket::Client.connect(endpoint) do |connection|
          after_start_connection
          self.connection = connection
          self.task = task
          yield
        ensure

          leave
        end
      end
    end

    def await(retry_count = 0)
      connect_to_ws do
        send_msg("phx_join")

        while message = connection.read
          RubyCI.debug("ws#msg_received: #{message.inspect}")

          response = message.dig(:payload, :response)

          case response&.dig(:event) || message[:event]
          when "phx_error"
            raise("[RubyCI] Unexpected error")
          when "join"
            handle_join(response)
          when "deq_request"
            handle_deq_request(response)
          when "deq"
            if (tests = response[:tests]).any?
              result = @on[:deq].call(tests)
              task.async do
                send_msg("deq", result)
              end
            else
              break
            end
          when "error"
            raise(response.inspect)
          else
            puts response
          end
        end
      end
    end

    private

    def leave
      send_msg("leave")
      connection.close
    rescue StandardError => e
      # noop
    end

    # https://github.com/bblimke/webmock/blob/b709ba22a2949dc3bfac662f3f4da88a21679c2e/lib/webmock/http_lib_adapters/async_http_client_adapter.rb#L8
    def before_start_connection
      if defined?(WebMock::HttpLibAdapters::AsyncHttpClientAdapter)
        WebMock::HttpLibAdapters::AsyncHttpClientAdapter.disable!
      end
    end

    # https://github.com/bblimke/webmock/blob/b709ba22a2949dc3bfac662f3f4da88a21679c2e/lib/webmock/http_lib_adapters/async_http_client_adapter.rb#L8
    def after_start_connection
      if defined?(WebMock::HttpLibAdapters::AsyncHttpClientAdapter)
        WebMock::HttpLibAdapters::AsyncHttpClientAdapter.enable!
      end
    end

    def handle_join(response)
      @node_index = response[:node_index]

      RubyCI.debug("NODE_INDEX: #{@node_index}")

      send_msg("enq", { tests: @on[:enq_request].call }) if node_index.zero?

      send_msg("deq") if response[:state] == "running"
    end

    def handle_deq_request(_response)
      send_msg("deq")
    end

    def ref
      @ref += 1
    end

    def topic
      "test_orchestrator:#{run_key}-#{RubyCI.configuration.build_id}"
    end

    def endpoint
      params = URI.encode_www_form({
                                     build_id: RubyCI.configuration.build_id,
                                     run_key: run_key,
                                     secret_key: RubyCI.configuration.secret_key,
                                     branch: RubyCI.configuration.branch,
                                     commit: RubyCI.configuration.commit,
                                     commit_msg: RubyCI.configuration.commit_msg,
                                     author: RubyCI.configuration.author.to_json
                                   })

      url = "wss://#{RubyCI.configuration.api_url}/test_orchestrators/socket/websocket?#{params}"

      Async::HTTP::Endpoint.parse(url, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
    end
  end
end
