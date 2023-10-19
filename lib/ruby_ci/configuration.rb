# frozen_string_literal: true

module RubyCI
  class Configuration
    attr_accessor :run_key, :build_id, :commit_msg, :commit, :branch,
                  :api_url, :secret_key, :author

    def initialize
      # Settings defaults
      self.run_key = nil
      self.build_id = guess_build_id
      self.commit = guess_commit
      self.commit_msg = `git log -1 --pretty=%B`.chomp
      self.branch = guess_branch
      self.api_url = ENV["RUBY_CI_API_URL"] || "api.fast.ci"
      self.secret_key = ENV.fetch("RUBY_CI_SECRET_KEY")
      self.author = guess_author
    end

    def reset
      initialize
    end

    def run_key
      @run_key || raise("#run_key was not configured.")
    end

    def guess_author
      author_Line = `git show | grep Author:`
      name, email = author_Line.scan(/Author: (.*) <(.*)>/).first
      {
        name: name,
        email: email
      }
    end

    def guess_build_id
      %w[RBCI_BUILD_ID GITHUB_RUN_ID BUILD_ID CIRCLE_BUILD_NUM].find do |keyword|
        key = ENV.keys.find { |k| k[keyword] }
        break ENV[key] if key && ENV[key]
      end || guess_commit
    end

    def guess_commit
      %w[RBCI_COMMIT _COMMIT _SHA1 _SHA].find do |keyword|
        key = ENV.keys.find { |k| k[keyword] }
        break ENV[key] if key && ENV[key]
      end || `git rev-parse --short HEAD`.chomp
    end

    def guess_branch
      %w[RBCI_BRANCH _BRANCH _REF].find do |keyword|
        key = ENV.keys.find { |k| k[keyword] }
        break ENV[key] if key && ENV[key]
      end || `git rev-parse --abbrev-ref HEAD`.chomp
    end
  end
end
