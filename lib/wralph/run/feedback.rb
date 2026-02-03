# frozen_string_literal: true

begin
  require 'reline'
rescue LoadError
  # Fallback for older Ruby versions - reline was added in Ruby 2.7
  # Use basic $stdin.gets for multiline input
end

require_relative '../interfaces/repo'
require_relative '../interfaces/print'
require_relative '../interfaces/shell'
require_relative '../interfaces/agent'
require_relative '../utils'
require_relative '../config'
require_relative 'init'
require_relative 'iterate_ci'

module Wralph
  module Run
    module Feedback
      def self.run(issue_number)
        Init.ensure_initialized!

        branch_name = "issue-#{issue_number}".freeze
        plan_file = Interfaces::Repo.plan_file(issue_number)

        stdout, = Interfaces::Shell.run_command('git branch --show-current')
        current_branch = stdout.strip
        Interfaces::Shell.switch_into_worktree(branch_name, create_if_not_exists: false)

        # Check that the Pull Request is open
        stdout, = Interfaces::Shell.run_command("gh pr view #{branch_name} --json state -q .state")
        if stdout.strip != 'OPEN'
          Interfaces::Print.error "Pull Request #{issue_number} is not open. Please open it and try again."
          exit 1
        end

        # Get input from user on changes to make to the Pull Request
        Interfaces::Print.info "Please review the changes to the Pull Request and provide feedback on what changes to make."
        Interfaces::Print.info "  - Press Enter for a new line"
        Interfaces::Print.info "  - Press Enter three times to submit"

        if defined?(Reline)
          changes = Reline.readmultiline("> ", true) do |buffer|
            # Submit when the last line is empty (user pressed Enter on empty line)
            # Buffer ends with "\n\n" when user presses Enter on an empty line
            # We need content before the empty line
            next false if buffer.empty? || buffer == "\n"

            # Check if buffer ends with double newline (empty line entered)
            if buffer.end_with?("\n\n\n")
              # Verify we have at least one non-empty line
              lines = buffer.split("\n")
              lines.any? { |line| !line.strip.empty? }
            else
              false
            end
          end
          # Remove the trailing empty line if present
        else
          # Fallback for older Ruby versions without reline
          changes = ""
          puts "> "
          loop do
            line = $stdin.gets
            break if line.nil? || line.strip.empty?

            changes += line
            # Check if we've had two consecutive empty lines
            if changes.end_with?("\n\n")
              changes = changes.chomp
              break
            end
          end
        end
        changes = changes.chomp

        # Ask the agent to make the changes
        Interfaces::Print.info "Asking the agent to evaluate your comments to the Pull Request..."
        config = Config.load
        prompt_template = config.prompts&.feedback

        instructions = Utils.prompt_sub(
          prompt_template,
          {
            plan_file: plan_file,
            branch_name: branch_name,
            changes: changes
          }
        )

        # Run claude code with instructions
        claude_output = Interfaces::Agent.run(instructions)
        puts "CLAUDE_OUTPUT: #{claude_output}"

        # Check if fixes were pushed
        if claude_output.include?('FIXES_PUSHED')
          Interfaces::Print.success 'Fixes have been pushed. Waiting before checking build status again...'
          sleep 60 # Wait a bit for CircleCI to pick up the new commit
        else
          Interfaces::Print.error 'Could not confirm that fixes were pushed. Please check manually.'
          exit 1
        end

        IterateCI.run(issue_number)

        Interfaces::Shell.switch_into_worktree(current_branch)
      end
    end
  end
end
