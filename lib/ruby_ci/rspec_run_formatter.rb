# frozen_string_literal: true
require "stringio"

module RubyCI
  class RspecRunFormatter
    RSpec::Core::Formatters.register self,
    :start,
    :example_group_started,
    :example_started,
    :example_passed,
    :example_failed,
    :example_pending,
    :example_group_finished,
    :close

    def initialize(output)
      @output = output
      @event_output = {}
      @is_failed = false
      @current_path = []
      @current_path_started_at = []
      @max_heap_live_num = 0
      @dup_stdout = STDOUT.clone
      @events = []

      $stdout = StringIO.new()
    end

    def time_now
      time_frozen? ? Timecop.return { Time.now } : Time.now
    end

    def time_frozen?
      return unless defined?(Timecop)
      Timecop.frozen?
    end

    def rspec_runner_index
      ENV["TEST_ENV_NUMBER"]
    end

    def send_events
      if @events.length > 0
        json_events = {
          build_id: RubyCI.configuration.orig_build_id,
          compressed_data: Base64.strict_encode64(Zlib::Deflate.deflate(JSON.fast_generate(@events), 9)),
        }

        RubyCI.send_events(json_events)

        @events = []
      end
    end
  
    def check_heap_live_num
      @max_heap_live_num = [@max_heap_live_num, GC.stat[:heap_live_slots] || GC.stat[:heap_live_num]].max
    end

    def passed?
      !@is_failed
    end

    def start(start_notification)
      @output.print "Starting rspec run"
      # $stderr = $stdout
  
      data = {
        load_time: start_notification.load_time,
        example_count: start_notification.count,
        started_at: time_now.to_s
      }
  
      return if running_only_failed? ||
        running_gem_or_engine? ||
        ENV["EXTRA_SLOWER_RUN"]
  
      msg(:start, data)
    end
  
    def close(null_notification)
      @output.print "Finished rspec run"
      # check_heap_live_num
      msg(:gc_stat, GC.stat.merge(max_heap_live_num: @max_heap_live_num))
      unless running_only_failed? || ENV["EXTRA_SLOWER_RUN"] || running_gem_or_engine?
        msg(:close, {final_output: get_output})
      end
      send_events
      $stdout = @dup_stdout
    end
  
    def example_group_started(group_notification)
      metadata = group_notification.group.metadata
      @current_path_started_at << time_now
  
      if @current_path.size == 0
        @example_failed_index = 0
        file_path = metadata[:file_path].gsub("./".freeze, "".freeze)
        file_path = [ENV["DIR_PREFIX"], file_path].join("/") if ENV["DIR_PREFIX"]
        @current_path << file_path
      end
  
      @current_path << id(metadata)
  
      msg(:group_started, [
        path_with_file(group_notification.group),
        {
          line_number: metadata[:line_number],
          description: metadata[:description],
        }
      ])
    end
  
    def example_started(example_notification)
      @output_before = get_output
    end
  
    def example_passed(example_notification)
      metadata = example_notification.example.metadata
      broadcast_example_finished(serialize_example(metadata, "passed".freeze), example_notification.example)
      @output.print RSpec::Core::Formatters::ConsoleCodes.wrap('.', :success)
    end
  
    def example_failed(example_notification)
      @example_failed_index += 1
      metadata = example_notification.example.metadata
      fully_formatted = example_notification.fully_formatted(@example_failed_index, ::RSpec::Core::Formatters::ConsoleCodes)
  
      broadcast_example_finished(
        serialize_example(metadata, "failed".freeze, fully_formatted),
        example_notification.example
      )
      @output.print RSpec::Core::Formatters::ConsoleCodes.wrap('F', :failure)
    end
  
    def example_pending(example_notification)
      metadata = example_notification.example.metadata
      broadcast_example_finished(
        serialize_example(metadata, "pending".freeze),
        example_notification.example
      )
      @output.print RSpec::Core::Formatters::ConsoleCodes.wrap('*', :pending)
    end

    def example_group_finished(group_notification)
      run_time = time_now - @current_path_started_at.pop
      if (run_time < 0) || (run_time > 2400)
        run_time = 0.525
      end
        msg(:group_finished, [path_with_file(group_notification.group), {run_time: run_time}])
        # msg(:group_finished, [@current_path.map(&:to_s), {run_time: run_time}])
      @current_path.pop
      @current_path.pop if @current_path.size == 1 # Remove the file_path at the beggining
    end

    def path_with_file(group)
      file_path = group.parent_groups.last.file_path.gsub("./".freeze, "".freeze)
  
      group.metadata[:scoped_id].split(":").unshift(file_path)
    end

    private

    def running_gem_or_engine?
      !!ENV["DIR_PREFIX"]
    end
  
    def running_only_failed?
      !!ENV["RERUN_FAILED_FILES"]
    end
  
    def serialize_example(metadata, status, fully_formatted = nil)
      run_time = metadata[:execution_result].run_time
      if (run_time < 0) || (run_time > 2400)
        run_time = 0.525
      end
  
      result = {
        id: id(metadata),
        status: status,
        line_number: metadata[:line_number].to_s,
        description: metadata[:description],
        run_time: run_time,
        fully_formatted: fully_formatted,
        scoped_id: metadata[:scoped_id],
      }.compact
  
      result[:gem_or_engine] = true if running_gem_or_engine?
  
      if running_only_failed?
        result[:reruned] = true
      elsif status == "failed" && !running_gem_or_engine?
        File.write('tmp/rspec_failures', "#{@current_path.first}[#{metadata[:scoped_id]}]", mode: 'a+')
      end
  
      if status == "failed"
        img_path = metadata.dig(:screenshot, :image) ||
          fully_formatted&.scan(/\[Screenshot Image\]: (.*)$/).flatten.first&.strip&.chomp ||
          fully_formatted&.scan(/\[Screenshot\]: (.*)$/).flatten.first&.strip&.chomp
  
        if img_path && File.exist?(img_path)
          STDOUT.puts "SCREENSHOT!"
          result[:screenshots_base64] ||= []
          result[:screenshots_base64] << Base64.strict_encode64(File.read(img_path))
        end
      end
      @last_example_finished_at = time_now
      # TODO annalyze this: run_time: metadata[:execution_result].run_time,
      result
    end

    def msg(event, data)
      @events << ["rspec_#{event}".upcase, [rspec_runner_index, data]]
    end

    def id(metadata)
      metadata[:scoped_id].split(":").last || raise("No scoped id")
    end

    def broadcast_example_finished(data, example)
      msg(:example_finished, [
        path_with_file(example.example_group),
        data.merge(output_inside: get_output, output_before: @output_before)
      ])
  
      send_events if @events.size > 100
    end

    def get_output
      return if $stdout.pos == 0
      $stdout.rewind
      res = $stdout.read
      $stdout.flush
      $stdout.rewind
      res
    end
  end
end