module RubyCI
  module SimpleCov
    def self.included base
      base.instance_eval do
        def write_last_run(result)
          ::SimpleCov::LastRun.write(result:
            result.coverage_statistics.transform_values do |stats|
              round_coverage(stats.percent)
            end)

          RubyCI.report_simplecov(result.to_json)
        end
      end
    end
  end
end