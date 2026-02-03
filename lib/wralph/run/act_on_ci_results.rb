# frozen_string_literal: true

require_relative '../interfaces/repo'
require_relative '../interfaces/print'
require_relative '../interfaces/shell'
require_relative 'iterate_ci'

module Wralph
  module Run
    module ActOnCIResults
      def self.run(issue_number)
        branch_name = "issue-#{issue_number}".freeze

        # Check current branch to return to later
        stdout, = Interfaces::Shell.run_command('git branch --show-current')
        current_branch = stdout.strip

        # Switch into the worktree (will fail if it doesn't exist, or just return if already there)
        Interfaces::Shell.switch_into_worktree(branch_name, create_if_not_exists: false)

        # Resolve PR number from branch name
        pr_number = Interfaces::Repo.get_pr_from_branch_name(branch_name)

        if pr_number.nil?
          Interfaces::Print.error "Could not find PR for branch #{branch_name}. Please ensure a PR exists."
          exit 1
        end

        Interfaces::Print.success "Found PR ##{pr_number}"
        Interfaces::Print.info 'Proceeding to monitor CircleCI build status...'

        # Run the CI iteration loop
        IterateCI.run(issue_number, pr_number)

        # Return to the original branch
        Interfaces::Shell.switch_into_worktree(current_branch, create_if_not_exists: false)
      end
    end
  end
end
