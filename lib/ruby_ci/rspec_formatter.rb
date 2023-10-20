# frozen_string_literal: true

module RubyCI
  class RspecFormatter
    attr_reader :current_test_key

    def initialize
      @output = {}
      @is_failed = false
    end

    def passed?
      !@is_failed
    end

    def current_test_key=(value)
      @current_test_key = value
    end

    def example_finished(notification)
      example =  notification.example
      metadata = example.metadata

      *example_group_ids, example_id = metadata[:scoped_id].split(":")

      file_output = @output[current_test_key] ||= {}

      example_group = example_group_ids.reduce(file_output) do |output, scope_id|
        output[scope_id] ||= {}
        output[scope_id]
      end

      example_group[example_id] = {
        run_time: example.execution_result.run_time,
        status: example.execution_result.status
      }

      if example.execution_result.status == :failed
        @is_failed = true
        example_group[example_id][:fully_formatted] =
          notification.fully_formatted(0, ::RSpec::Core::Formatters::ConsoleCodes)
      elsif metadata[:retry_attempts] && metadata[:retry_attempts] > 0
        example_group[example_id][:retry_attempts] = metadata[:retry_attempts]
        example_group[example_id][:fully_formatted] =
          example.set_exception metadata[:retry_exceptions].first.to_s
      end

      example_group[example_id]
    end

    def dump_and_reset
      output = @output
      @output = {}
      output
    end
  end
end