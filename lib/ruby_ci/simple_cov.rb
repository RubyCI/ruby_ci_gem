require_relative "simple_cov/reporting"

module RubyCI
  module SimpleCov
    if ENV['RBCI_REMOTE_TESTS'] == 'true' && ENV["SIMPLECOV_ACTIVE"] && ENV['DRYRUN'] != 'true'
      ::SimpleCov.send(:at_exit) do
        ::SimpleCov.result.format!

        config = {
          minimum_coverage: ::SimpleCov.minimum_coverage,
          maximum_coverage_drop: ::SimpleCov.maximum_coverage_drop,
          minimum_coverage_by_file: ::SimpleCov.minimum_coverage_by_file,
        }
        rspec_runner_index = ENV["TEST_ENV_NUMBER".freeze].to_i
        events = [['simplecov_config'.upcase, [ rspec_runner_index, config ]]]

        json_events = {
          build_id: RubyCI.configuration.orig_build_id,
          compressed_data: Base64.strict_encode64(Zlib::Deflate.deflate(JSON.fast_generate(events), 9)),
        }
  
        RubyCI.send_events(json_events)
      end

      module PrependSc
        def start(*args, &block)
          add_filter "tmp"
          merge_timeout 3600
          command_name "RSpec_#{ENV["TEST_ENV_NUMBER".freeze].to_i}"

          if ENV["NO_COVERAGE"]
            use_merging false
            return
          end
          super
        end
      end
      ::SimpleCov.singleton_class.prepend(PrependSc)

      module Scf
        def format!
          return if ENV["NO_COVERAGE"]
          rspec_runner_index = ENV["TEST_ENV_NUMBER".freeze].to_i

          original_result_json = if ENV['CI_PROJECT_DIR'].present?
            JSON.fast_generate(original_result.transform_keys {|key| key.sub(ENV['CI_PROJECT_DIR'], '/app') })
          else
            JSON.fast_generate(original_result)
          end
          compressed_data = Base64.strict_encode64(Zlib::Deflate.deflate(original_result_json, 9))
          events = [['simplecov_result'.upcase, [ rspec_runner_index, compressed_data ]]]

          json_events = {
            build_id: RubyCI.configuration.orig_build_id,
            compressed_data: Base64.strict_encode64(Zlib::Deflate.deflate(JSON.fast_generate(events), 9)),
          }
    
          RubyCI.send_events(json_events)
          super
        end
      end

      ::SimpleCov::Result.prepend(Scf)
    else
      ::SimpleCov.send(:include, RubyCI::SimpleCov::Reporting) unless ENV['DRYRUN'] == 'true'
    end
  end
end