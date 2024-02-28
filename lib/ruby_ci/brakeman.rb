require 'ruby_ci/brakeman/commandline'
require 'ruby_ci'
require 'base64'
require 'zlib'

module RubyCI
  module Brakeman
    def self.start
      RubyCI::Brakeman::Commandline.start(output_files: ['tmp/brakeman.json'], ensure_ignore_notes: false)

      content = File.read('tmp/brakeman.json')
      compressed_data = ::Base64.strict_encode64(Zlib::Deflate.deflate(content, 9))
      RubyCI.report_brakeman(compressed_data, 'passed')
    end
  end
end