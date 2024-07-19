require 'ruby_ci/brakeman/commandline'
require 'ruby_ci'
require 'base64'
require 'zlib'

module RubyCI
  module Brakeman
    def self.start
      events = []
      events << ['running_brakeman_run'.upcase, {}]
      RubyCI::Brakeman::Commandline.start(output_files: ['tmp/brakeman.json'], ensure_ignore_notes: false)

      content = File.read('tmp/brakeman.json')
      compressed_data = ::Base64.strict_encode64(Zlib::Deflate.deflate(content, 9))

      events << ['running_brakeman_exit_status'.upcase, ['0', { exitstatus: 0, stderr: '', output: '', compressed_data: compressed_data ]]

      if ENV['RBCI_REMOTE_TESTS'] == 'true'
        json_events = {
          build_id: RubyCI.configuration.orig_build_id,
          compressed_data: Base64.strict_encode64(Zlib::Deflate.deflate(JSON.fast_generate(events), 9)),
        }
  
        RubyCI.send_events(json_events)
      else
        RubyCI.report_brakeman(compressed_data, 'passed')
      end
    end
  end
end