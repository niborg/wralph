# frozen_string_literal: true

require 'open3'
require 'json'
require_relative 'print'

module Wralph
  module Interfaces
    module Shell
      # Check if a command exists
      def self.command_exists?(cmd)
        system("which #{cmd} > /dev/null 2>&1")
      end

      # Run a command and return stdout, stderr, and status
      def self.run_command(cmd, raise_on_error: false)
        stdout, stderr, status = Open3.capture3(cmd)
        raise "Command failed: #{cmd}\n#{stderr}" if raise_on_error && !status.success?

        [stdout.chomp, stderr.chomp, status.success?]
      end

      def self.get_worktrees
        json_output, = run_command("wt list --format=json")
        JSON.parse(json_output.force_encoding('UTF-8'))
      end

      def self.switch_into_worktree(branch_name, create_if_not_exists: true)
        # Check if already in the target worktree
        stdout, = run_command('git branch --show-current')
        current_branch = stdout.strip
        if current_branch == branch_name
          Print.info "Already in worktree for branch #{branch_name}"
          return
        end

        # Check if any entry matches the branch name
        worktree = get_worktrees.find { |wt| wt['branch'] == branch_name }
        if worktree
          success = system("wt switch #{worktree['branch']}")
          unless success
            Print.error "Failed to switch to branch #{branch_name}"
            exit 1
          end
        elsif create_if_not_exists
          success = system("wt switch --create #{branch_name}")
          unless success
            Print.error "Failed to switch to branch #{branch_name}"
            exit 1
          end
          worktree = get_worktrees.find { |wt| wt['branch'] == branch_name }
        else
          Print.error "Worktree for branch #{branch_name} not found. Use --create to create it."
          exit 1
        end

        # Change the directory of the CURRENT Ruby process to the new worktree
        Dir.chdir(worktree['path'])
      end

      def self.ask_user_to_continue(message = 'Continue? (y/N) ')
        print message
        response = $stdin.gets.chomp
        exit 1 unless response =~ /^[Yy]$/
      end
    end
  end
end
