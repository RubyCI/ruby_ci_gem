# frozen_string_literal: true
require_relative "rspec_formatter"
require_relative "extract_definitions"

module RubyCI
  module DryrunRunnerPrepend
    def run(err, out)
      @rspec_started_at = Time.now
      super
    end

    def exit_code(examples_passed=false)
      run_time = Time.now - (@rspec_started_at || 1.second.ago)
      events = @world.non_example_failure ? [['RSPEC_DRYRUN', { failed_after: run_time, test_env_number: ENV["TEST_ENV_NUMBER"], data: 'error' }]] : [['RSPEC_DRYRUN', { succeed_after: run_time, test_env_number: ENV["TEST_ENV_NUMBER"] }]]
      STDOUT.puts events.inspect
      json_events = {
        build_id: RubyCI.configuration.orig_build_id,
        compressed_data: Base64.strict_encode64(Zlib::Deflate.deflate(JSON.fast_generate(events), 9)),
      }
      RubyCI.send_events(json_events)

      return @configuration.error_exit_code || @configuration.failure_exit_code if @world.non_example_failure
      return @configuration.failure_exit_code unless examples_passed

      0
    end
  end
end