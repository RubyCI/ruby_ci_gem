# frozen_string_literal: true

module RubyCI
  module RunnerPrepend
    def run_specs(example_groups)
      examples_count = @world.example_count(example_groups)

      example_groups = example_groups.reduce({}) do |acc, ex_group|
        if acc[ex_group.file_path]
          acc[ex_group.file_path] << ex_group
        else
          acc[ex_group.file_path] = [ex_group]
        end
        acc
      end

      RubyCI.configure { |c| c.run_key = "rspec" }

      RubyCI.ws.on(:enq_request) do
        example_groups.reduce({}) do |example_group_descriptions, (file, example_groups)|
          example_groups.each do |example_group|
            data = RubyCI::ExtractDescriptions.new.call(example_group, count: true)

            next if data[:test_count] == 0

            if example_group_descriptions[file]
              example_group_descriptions[file].merge!(data) do |k, v1, v2|
                v1 + v2
              end
            else
              example_group_descriptions[file] = data
            end
          end
        example_group_descriptions
        end
      end

      examples_passed = @configuration.reporter.report(examples_count) do |reporter|
        @configuration.with_suite_hooks do
          if examples_count == 0 && @configuration.fail_if_no_examples
            return @configuration.failure_exit_code
          end

          formatter = RubyCI::RspecFormatter.new

          reporter.register_listener(formatter, :example_finished)

          RubyCI.ws.on(:deq) do |tests|
            tests.each do |test|
              file, scoped_id = test.split(":", 2)
              Thread.current[:rubyci_scoped_ids] = scoped_id
              example_groups[file].each do |file_group|
                formatter.current_test_key = test

                file_group.run(reporter)
              end
            end

            formatter.dump_and_reset
          end

          RubyCI.await

          formatter.passed?
        end
      end

      exit_code(examples_passed)
    end

    def exit_code(examples_passed=false)
      return @configuration.error_exit_code || @configuration.failure_exit_code if @world.non_example_failure
      return @configuration.failure_exit_code unless examples_passed

      0
    end
  end
end