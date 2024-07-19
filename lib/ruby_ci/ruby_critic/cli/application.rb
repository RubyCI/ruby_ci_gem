# frozen_string_literal: true

require 'rubycritic/cli/application'
require 'ruby_ci'
require 'base64'
require 'zlib'

module RubyCI
  module RubyCritic
    module Cli
      class Application < ::RubyCritic::Cli::Application
        def execute
          events = []
          events << ['running_ruby_critic_run'.upcase, {}]
          status = super

          content = File.read('tmp/rubycritic/report.json')
          report = JSON.load(content)
          modules = report['analysed_modules']
          report['analysed_modules'] = {}
          modules.each do |mod|
            report['analysed_modules'][ mod['path'] ] = mod
            mod['smells'].each do |smell|
              location = smell['locations'].first
              start_line = location['line'] - 1
              end_line = start_line + 3
              lines = File.readlines(location['path'])[start_line..end_line]
              location['src'] = lines.join
              smell['locations'][0] = location
            end
          end

          compressed_data = ::Base64.strict_encode64(Zlib::Deflate.deflate(report.to_json, 9))
          events << ['running_ruby_critic_exit_status'.upcase, { exitstatus: status, output: '', compressed_data: compressed_data }]

          if ENV['RBCI_REMOTE_TESTS'] == 'true'
            json_events = {
              build_id: RubyCI.configuration.orig_build_id,
              compressed_data: Base64.strict_encode64(Zlib::Deflate.deflate(JSON.fast_generate(events), 9)),
            }
      
            RubyCI.send_events(json_events)
          else
            RubyCI.report_ruby_critic(compressed_data, 'passed')
          end
          return status
        end
      end
    end
  end
end