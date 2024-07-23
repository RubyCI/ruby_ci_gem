# frozen_string_literal: true

module RubyCI
  class RspecDryrunFormatter
    RSpec::Core::Formatters.register self,
    :start,
    :message,
    :example_passed,
    :example_failed,
    :example_pending,
    :example_group_finished,
    :example_group_started,
    :dump_summary,
    :close

    def initialize(output)
      @output = output
      @current_group_path = []
      @current_file = nil
      @current_file_count = 0
      @events = []
    end
  
    def message(message_notification)
      @output.print message_notification.message
      @output.print "\n"
    end
  
    def start(example_count)
      msg(:start, { "example_count" => example_count.count, "timestamp" => time_now })
    end
  
    def close(*args)
      msg(:close, { "timestamp" => time_now })
      send_events
    end
  
    def dump_summary(summary_notification)
    end
  
    def time_now
      time_frozen? ? Timecop.return { Time.now } : Time.now
    end
  
    def time_frozen?
      return unless defined?(Timecop)
      Timecop.frozen?
    end
  
    def example_passed(example_notification)
      example_finished(example_notification)
      @output.print RSpec::Core::Formatters::ConsoleCodes.wrap('.', :success)
    end

    def example_failed(example_notification)
      example_finished(example_notification)
      @output.print RSpec::Core::Formatters::ConsoleCodes.wrap('F', :failure)
    end
  
    def example_pending(example_notification)
      example_finished(example_notification)
      @output.print RSpec::Core::Formatters::ConsoleCodes.wrap('*', :pending)
    end
  
    def start_dump(_notification)
      output.puts
    end

    def example_group_finished(_group_notification)
      @current_group_path.pop
      if @current_group_path.empty? # its a file
        msg(:file_examples_count, [@current_file, @current_file_count])
        @current_file_count = 0
        @current_file = nil
      end
    end
  
    def example_group_started(group_notification)
      if @current_group_path.size == 0
        @current_file = group_notification.group.metadata[:file_path].gsub("./".freeze, "".freeze)
        @current_file_count = 0
      end
      @current_group_path << 1
    end

    private
  
    def example_finished(example_notification)
      @current_file_count += 1
    end
  
    def send_events
      return unless @events.length > 0
  
      json_events = {
        build_id: RubyCI.configuration.orig_build_id,
        compressed_data: Base64.strict_encode64(Zlib::Deflate.deflate(JSON.fast_generate(@events), 9)),
      }

      RubyCI.send_events(json_events)

      @events = []
    end
  
    def msg(event, data)
      @events << ["rspec_dryrun_#{event}".upcase, ['0', data]]
    end
  
    def get_scope_id(metadata)
      metadata[:scoped_id].split(":").last || raise("No scoped id")
    end
  end
end
