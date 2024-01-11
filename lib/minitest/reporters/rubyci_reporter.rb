module Minitest
  module Reporters
    class RubyciReporter
      attr_accessor :tests, :test_results

      def initialize
        @tests = {}
        @test_results = {}

        RubyCI.minitest_ws.on(:enq_request) do
          tests
        end

        RubyCI.minitest_ws.on(:deq) do |api_tests|
          test_results
        end
      end

      def prerecord(klass, name)
        id = test_id(name)
        path = test_path(klass.name)

        test_results[path] ||= { run_time: 0.0, file_status: 'pending', test_count: 0, test_counters: { failed: 0, passed: 0, pending: 0 }, '1' => {} }
        test_results[path][:test_count] += 1
        test_results[path]['1'][id] ||= { status: 'pending' }
        test_results[path]['1'][id][:start] = Minitest.clock_time

        tests[path] ||= { run_time: 0.0, file_status: 'pending', test_count: 0, test_counters: { failed: 0, passed: 0, pending: 0 }, '1' => {} }
        tests[path][:test_count] += 1
        tests[path]['1'][id] ||= { status: 'pending' }
      end

      def record(result)
        id = test_id(result.name)
        path = test_path(result.klass)

        test_results[path]['1'][id][:end] = Minitest.clock_time
        test_results[path]['1'][id][:run_time] = test_results[path]['1'][id][:end] - test_results[path]['1'][id][:start]
        test_results[path]['1'][id][:status] = result_status(result).to_s
        test_results[path][:test_counters][result_status(result)] += 1
        test_results[path][:run_time] += test_results[path]['1'][id][:run_time]
      end

      def report
        test_results.each do |path, file_results|
          file_status = 'pending'
          file_results['1'].each do |id, test_result|
            if (test_result[:status] == 'passed') && (file_status != 'failed')
              file_status = 'passed'
            elsif file_status == 'failed'
              file_status = 'failed'
            end
          end
          test_results[path][:file_status] = file_status
        end

        RubyCI.minitest_await
      end

      def method_missing(method, *args)
        return
      end

      private

      def test_id(name)
        test_name = name.split('test_').last
        test_name = test_name[2..-1] if test_name.starts_with?(': ')

        return test_name.strip
      end

      def test_path(klass)
        return Object.const_source_location(klass)[0].gsub(Regexp.new("^#{::Rails.root}/"), '')
      end

      def result_status(result)
        if result.passed?
          :passed
        elsif result.skipped?
          :skipped
        else
          :failed
        end
      end
    end
  end
end