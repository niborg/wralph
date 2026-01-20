# frozen_string_literal: true

require_relative '../interfaces/print'
require_relative '../interfaces/shell'
require_relative 'init'

module Wralph
  module Run
    module Remove
      def self.run(issue_number)
        Init.ensure_initialized!

        branch_name = "issue-#{issue_number}".freeze

        # Delete local branch
        _, _, success = Interfaces::Shell.run_command("git branch -D #{branch_name}")
        if success
          Interfaces::Print.info "Deleted branch '#{branch_name}' locally"
        else
          Interfaces::Print.warning "Branch '#{branch_name}' not found locally"
        end

        # Delete remote branch
        _, _, success = Interfaces::Shell.run_command("git push origin --delete #{branch_name}")
        if success
          Interfaces::Print.info "Deleted branch '#{branch_name}' on remote"
        else
          Interfaces::Print.warning "Branch '#{branch_name}' not found on remote"
        end

        # Remove worktree
        _, _, success = Interfaces::Shell.run_command("wt remove #{branch_name}")
        if success
          Interfaces::Print.info "Removed worktree for branch '#{branch_name}'"
        else
          Interfaces::Print.warning "Worktree for branch '#{branch_name}' not found"
        end

        Interfaces::Print.success "Cleanup completed for issue ##{issue_number}"
      end
    end
  end
end
