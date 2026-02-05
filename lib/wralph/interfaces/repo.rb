# frozen_string_literal: true

require_relative 'shell'
require_relative '../config'
require_relative '../utils'

module Wralph
  module Interfaces
    module Repo
      def self.install_dir
        @install_dir ||= begin
          # If we're running from source (lib/wralph/interfaces/repo.rb exists relative to bin/)
          script_path = File.realpath($0) if $0
          if script_path && File.exist?(script_path)
            # Go up from bin/wralph to repo root
            File.expand_path(File.join(File.dirname(script_path), '..'))
          else
            # Fallback: use __dir__ from this file, go up to repo root
            File.expand_path(File.join(__dir__, '..', '..', '..'))
          end
        end
      end

      def self.repo_root
        # Find git repository root from current working directory
        dir = Dir.pwd
        loop do
          return dir if File.directory?(File.join(dir, '.git'))

          parent = File.dirname(dir)
          break if parent == dir

          dir = parent
        end
        Dir.pwd # Fallback to current directory
      end

      def self.wralph_dir
        File.join(repo_root, '.wralph')
      end

      def self.plans_dir
        File.join(wralph_dir, 'plans')
      end

      def self.tmp_dir
        File.join(repo_root, 'tmp')
      end

      def self.plan_file(issue_number)
        File.join(plans_dir, "plan_#{issue_number}.md")
      end

      def self.env_file
        File.join(repo_root, '.env')
      end

      def self.secrets_file
        File.join(wralph_dir, 'secrets.yaml')
      end

      def self.config_file
        File.join(wralph_dir, 'config.yaml')
      end

      def self.failure_details_file(branch_name, retry_count)
        # Sanitize branch name to be safe for use in filenames (replace / with -)
        safe_branch_name = branch_name.gsub('/', '-')
        File.join(tmp_dir, "#{safe_branch_name}_failure_details_#{retry_count}_#{retry_count}.txt")
      end

      def self.fixtures_dir
        File.join(__dir__, '..', 'fixtures')
      end

      def self.fixture_file(filename)
        File.join(fixtures_dir, filename)
      end

      def self.get_pr_from_branch_name(branch_name)
        stdout, = Shell.run_command("gh pr list --head #{branch_name} --json number -q '.[0].number'")
        pr_number = stdout.strip
        pr_number.empty? || pr_number == 'null' ? nil : pr_number
      end

      def self.branch_name(identifier)
        config = Config.load
        template = config.repo&.branch_name || "issue-\#{identifier}"
        Utils.prompt_sub(template, identifier: identifier)
      end
    end
  end
end
