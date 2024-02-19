module RubyCI
  module SimpleCov
    module Reporting
      def self.included base
        base.instance_eval do
          if ENV['RUBY_CI_SECRET_KEY'].present?
            def write_last_run(result)
              ::SimpleCov::LastRun.write(result:
                result.coverage_statistics.transform_values do |stats|
                  round_coverage(stats.percent)
                end)

              source = {}

              result.source_files.each do |source_file|
                source[source_file.filename.gsub(root, '')] = source_file.src
              end

              result_json = {}

              result.as_json.each do |command, data|
                result_json[command] = data
                data['coverage'].clone.each do |src, file_data|
                  result_json[command]['coverage'].delete(src)

                  file_data['src'] = source[src.gsub(root, '')]

                  result_json[command]['coverage'][src.gsub(root, '')] = file_data
                end
              end

              RubyCI.report_simplecov(result_json.to_json)
            end
          end
        end
      end
    end
  end
end