require 'brakeman'
require 'brakeman/commandline'

module RubyCI
  module Brakeman
    class Commandline < ::Brakeman::Commandline
      def self.quit exit_code = 0, message = nil
        warn message if message
      end
    end
  end
end
