module Minitest
  module Reporters
    class Suite
      attr_reader :name
      def initialize(name)
        @name = name
      end

      def ==(other)
        name == other.name
      end

      def eql?(other)
        self == other
      end

      def hash
        name.hash
      end

      def to_s
        name.to_s
      end
    end

    class RubyciReporter
      attr_accessor :tests, :test_results, :ids

      def initialize
        @tests = {}
        @test_results = {}
        @ids = {}
        @events = []

        $stdout = StringIO.new()
      end

      def start
        test_count = Runnable.runnables.sum { |s| s.runnable_methods.count }
        msg('start', { test_count: test_count })
        @events << ['run_minitest'.upcase, { started_at: Time.current }]
        send_events if ENV['RBCI_REMOTE_TESTS'] == 'true'
      end
      
      def get_output
        return if $stdout.pos == 0
        $stdout.rewind
        res = $stdout.read
        $stdout.flush
        $stdout.rewind
        return unless res
        res.strip.chomp if res.strip.chomp != ""
      end
      
      def before_test(test)
        $stdout = StringIO.new()
        description = test_description(test.name)
        path = test_path(test.class.name)

        debug("PRERECORD: #{test.class.name} - #{path}")
        test_results[path] ||= { run_time: 0.0, file_status: 'pending', test_count: 0, test_counters: { failed: 0, passed: 0, pending: 0 }, '1' => { description: test.class.name } }
        test_results[path][:test_count] += 1
        debug("PRERECORD: #{test_results.inspect}")

        id = (test_results[path]['1'].keys.size + 1).to_s
        ids[description] = id

        test_results[path]['1'][id] ||= { status: 'pending', description: description }
        test_results[path]['1'][id][:start] = Minitest.clock_time

        tests[path] ||= { run_time: 0.0, file_status: 'pending', test_count: 0, test_counters: { failed: 0, passed: 0, pending: 0 }, '1' => {} }
        tests[path][:test_count] += 1
        tests[path]['1'][id] ||= { status: 'pending' }
      end

      def prerecord(klass, name)
      end

      def record(result)
        test_finished(result)
        description = test_description(result.name)
        id = ids[description]
        path = test_path(result.klass)

        debug("RECORD: #{result.klass} - #{path}")
        debug("RECORD: #{test_results.inspect} - #{path}")

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
            next if id == :description
            if (test_result[:status] == 'passed') && (file_status != 'failed')
              file_status = 'passed'
            elsif file_status == 'failed'
              file_status = 'failed'
            end
          end
          test_results[path][:file_status] = file_status
        end

        if ENV['RBCI_REMOTE_TESTS'] == 'true'
          send_events
        end
      end

      def passed?
        results = []
        test_results.map do |path, file_results|
          file_results['1'].each do |id, test_result|
            next if id == :description
            if test_result[:status] == 'failed'
              results << false
            else
              results << true
            end
          end
        end

        pass = results.any? {|result| !result }

        if pass
          @events << ['run_minitest'.upcase, { succeed_after: 1 }]
        else
          @events << ['run_minitest'.upcase, { failed_after: 1 }]
        end
        send_events if ENV['RBCI_REMOTE_TESTS'] == 'true'

        return pass
      end

      def method_missing(method, *args)
        return
      end
      
      protected

      def before_suite(suite)
      end

      def after_suite(_suite)
      end

      def record_print_status(test)
        test_name = test.name.gsub(/^test_: /, "test:")
        print pad_test(test_name)
        print_colored_status(test)
        print(" (%.2fs)" % test.time) unless test.time.nil?
        puts
      end
      
      def record_print_failures_if_any(test)
        if !test.skipped? && test.failure
          print_info(test.failure, test.error?)
          puts
        end
      end
      
      def screenshots_base64(output)
        return unless output
        img_path = output&.scan(/\\[Screenshot Image\\]: (.*)$/)&.flatten&.first&.strip&.chomp ||
          output&.scan(/\\[Screenshot\\]: (.*)$/)&.flatten&.first&.strip&.chomp

        if img_path && File.exist?(img_path)
          STDOUT.puts "SCREENSHOT!"
          Base64.strict_encode64(File.read(img_path))
        end
      end
      
      def test_finished(test)
        output = get_output

        location = if !test.source_location.join(":").start_with?(::Rails.root.join('vendor').to_s)
                    test.source_location.join(":")
                    else
                    if (file = `cat #{::Rails.root.join('vendor', 'bundle', 'minitest_cache_file').to_s} | grep "#{test.klass} => "`.split(" => ").last&.chomp)
                      file + ":"
                    else
                      file = `grep -rw "#{::Rails.root.to_s}" -e "#{test.klass} "`.split(":").first
                      `echo "#{test.klass} => #{file}" >> #{::Rails.root.join('vendor', 'bundle', 'minitest_cache_file').to_s}`
                      file + ":"
                    end
                    end

        fully_formatted = if test.failure
                            fully_formatted = "\n" + test.failure.message.split("\n").first

                            test.failure.backtrace.each do |l|
                              if !l["/cache/"]
                                fully_formatted << "\n    \e[36m" + l + "\033[0m"
                              end
                            end

                            fully_formatted
                          end

                          output_inside = output&.split("\n")&.select do |line|
                            !line["Screenshot"]
                          end&.join("\n")
        event_data = {
          test_class: Suite.new(test.klass),
          test_name: test.name.gsub(/^test_\\d*/, "").gsub(/^test_: /, "test:").gsub(/^_/, "").strip,
          assertions_count: test.assertions,
          location: location,
          status: status(test),
          run_time: test.time,
          fully_formatted: fully_formatted,
          output_inside: output_inside,
          screenshots_base64: [screenshots_base64(output)]
        }

        msg('test_finished', event_data)
        if ENV['RBCI_REMOTE_TESTS'] == 'true'
          send_events if @events.length >= 10
        end
      end
      
      def status(test)
        if test.passed?
          "passed"
        elsif test.error?
          "error"
        elsif test.skipped?
          "skipped"
        elsif test.failure
          "failed"
        else
          raise("Status not found")
        end
      end

      private

      def msg(event, data)
        @events << ["minitest_#{event}".upcase, data]   
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

      def test_description(name)
        test_name = name.split('test_').last
        test_name = test_name[2..-1] if test_name.starts_with?(': ')

        return test_name.strip
      end

      def test_path(klass)
        return "./#{Object.const_source_location(klass)[0].gsub(Regexp.new("^#{::Rails.root}/"), '')}"
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

      def debug(msg)
        STDOUT.puts msg if ENV['RBCY_DEBUGGING'] == 'true'
      end
    end
  end
end