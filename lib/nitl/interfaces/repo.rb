# frozen_string_literal: true

module Nitl
  module Interfaces
    module Repo
      def self.install_dir
        @install_dir ||= begin
          # If we're running from source (lib/nitl/interfaces/repo.rb exists relative to bin/)
          script_path = File.realpath($0) if $0
          if script_path && File.exist?(script_path)
            # Go up from bin/nitl to repo root
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

      def self.nitl_dir
        File.join(repo_root, '.nitl')
      end

      def self.plans_dir
        File.join(nitl_dir, 'plans')
      end

      def self.tmp_dir
        File.join(repo_root, 'tmp')
      end

      def self.plan_file(issue_number)
        File.join(plans_dir, "plan_gh_issue_no_#{issue_number}.md")
      end

      def self.env_file
        File.join(repo_root, '.env')
      end

      def self.secrets_file
        File.join(nitl_dir, 'secrets.yaml')
      end

      def self.failure_details_file(branch_name, retry_count)
        File.join(tmp_dir, "#{branch_name}_failure_details_#{retry_count}_#{retry_count}.txt")
      end
    end
  end
end
