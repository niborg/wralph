# frozen_string_literal: true

require_relative '../interfaces/repo'
require_relative '../interfaces/print'
require_relative '../interfaces/shell'
require_relative '../interfaces/agent'
require_relative 'iterate_ci'

module Nitl
  module Run
    module ExecutePlan
      def self.run(issue_number)
        plan_file = Interfaces::Repo.plan_file(issue_number)

        unless File.exist?(plan_file)
          Interfaces::Print.error "Plan file '#{plan_file}' not found. Please create a plan first."
          exit 1
        end

        branch_name = "issue-#{issue_number}".freeze
        current_branch = `git branch --show-current`.strip # To switch back later
        Interfaces::Shell.switch_into_worktree(branch_name)

        execution_instructions = <<~EXECUTION_INSTRUCTIONS
          You previously created a plan to solve GitHub issue ##{issue_number}. You can find the plan in the file: `#{plan_file}`. You have been placed in a git worktree for the branch `#{branch_name}`.

          Do as follows:

          1. Execute your plan:
             - Make the necessary changes to solve the issue
             - Commit your changes (including the plan) with a descriptive message that references the issue
             - Push the branch to GitHub
             - Create a pull request, referencing the issue in the body like "Fixes ##{issue_number}"

          2. After creating the PR, output the PR number and its URL so I can track it.

          Please proceed with these steps.
        EXECUTION_INSTRUCTIONS

        # Run claude code with instructions
        Interfaces::Print.info "Running Claude Code to execute the plan #{plan_file}..."
        claude_output = Interfaces::Agent.run(execution_instructions)
        puts "CLAUDE_OUTPUT: #{claude_output}"

        # Extract PR number from output (look for patterns like "PR #123", "**PR #123**", or "Pull Request #123")
        # Try multiple patterns in order of specificity to avoid false matches
        pr_number = nil

        # Pattern 1: Look for PR in URL format (most reliable and unambiguous)
        # Matches: https://github.com/owner/repo/pull/774
        Interfaces::Print.info "Extracting PR number from output by looking for the PR URL pattern..."
        pr_number = claude_output.match(%r{github\.com/[^/\s]+/[^/\s]+/pull/(\d+)}i)&.[](1)

        # Pattern 2: Look for "PR Number:" followed by optional markdown formatting and the number
        # This handles formats like "PR Number: **#774**" or "PR Number: #774"
        if pr_number.nil?
          # Match "PR Number:" followed by optional whitespace, optional markdown bold, optional #, then digits
          Interfaces::Print.warning "Extracting PR number from output by looking for the PR Number pattern..."
          pr_number = claude_output.match(/PR\s+Number\s*:\s*(?:\*\*)?#?(\d+)/i)&.[](1)
        end

        # Pattern 3: Look for "PR #" or "Pull Request #" at start of line or after heading markers
        if pr_number.nil?
          Interfaces::Print.warning "Extracting PR number from output by looking for the PR # pattern..."
          pr_number = claude_output.match(/(?:^|\n|###\s+)[^\n]*(?:PR|Pull Request)[:\s]+(?:\*\*)?#?(\d+)/i)&.[](1)
        end

        # Pattern 4: Fallback to simple pattern but exclude "Found PR" patterns
        if pr_number.nil?
          # Match PR but not if preceded by "Found" or similar words
          Interfaces::Print.warning "Extracting PR number from output by looking for the PR pattern..."
          pr_number = claude_output.match(/(?<!Found\s)(?:PR|Pull Request)[:\s]+(?:\*\*)?#?(\d+)/i)&.[](1)
        end

        # Pattern 5: Last resort - any PR pattern (but this might match false positives)
        if pr_number.nil?
          Interfaces::Print.warning "Extracting PR number from output by looking for the any PR pattern..."
          pr_number = claude_output.match(/(?:PR|Pull Request|pull request)[^0-9]*#?(\d+)/i)&.[](1)
        end

        if pr_number.nil?
          # Try to find PR by branch name
          Interfaces::Print.warning 'PR number not found in output, searching by branch name...'
          stdout, = Interfaces::Shell.run_command("gh pr list --head #{branch_name} --json number -q '.[0].number'")
          pr_number = stdout.strip
          pr_number = nil if pr_number.empty? || pr_number == 'null'
        end

        if pr_number.nil?
          Interfaces::Print.error 'Could not determine PR number. Please check the Claude Code output manually.'
          Interfaces::Print.error "Output: #{claude_output}"
          exit 1
        end

        Interfaces::Print.success "Found PR ##{pr_number}"
        Interfaces::Print.info 'Proceeding to monitor CircleCI build status...'

        # Step 2: Monitor CircleCI build and fix if needed
        IterateCI.run(issue_number, pr_number)

        Interfaces::Shell.switch_into_worktree(current_branch)
      end
    end
  end
end
