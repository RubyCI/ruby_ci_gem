module Minitest
  module Reporters
    class RubyciReporter
      attr_accessor :tests

      def initialize
        @tests = {}
      end

      def prerecord(klass, name)
        id = test_id(klass, name)

        tests[id] ||= {}
        tests[id][:start] = Minitest.clock_time
      end

      def record(result)
        id = test_id(result.klass, result.name)

        tests[id][:end] = Minitest.clock_time
        tests[id][:run_time] = tests[id][:end] - tests[id][:start],
        tests[id][:status] = result_stats(result)
      end

      def report
        puts tests.inspect
      end

      def method_missing(method, *args)
        return
      end

      private

      def test_id(klass, name)
        test_name = name.split('test_').last
        test_name = test_name[2..-1] if test_name.starts_with?(': ')

        return "#{klass}##{test_name.strip}"
      end

      def result_stats(result)
        if result.passed?
          'passed'
        elsif result.skipped?
          'skipped'
        elsif result.error?
          'error'
        else
          'failed'
        end
      end
    end
  end
end