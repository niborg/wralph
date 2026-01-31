# frozen_string_literal: true

require 'fileutils'
require_relative '../interfaces/repo'
require_relative '../interfaces/print'
require_relative '../interfaces/shell'
require_relative '../interfaces/agent'
require_relative '../interfaces/ci'

module Wralph
  module Run
    module IterateCI
      MAX_RETRIES = 10

      def self.run(issue_number, pr_number = nil)
        branch_name = "issue-#{issue_number}".freeze
        pr_number ||= begin
          stdout, = Interfaces::Shell.run_command("gh pr list --head #{branch_name} --json number -q '.[0].number'")
          pr_num = stdout.strip
          pr_num.empty? || pr_num == 'null' ? nil : pr_num
        end

        stdout, = Interfaces::Shell.run_command('git branch --show-current')
        current_branch = stdout.strip
        if current_branch != branch_name
          Interfaces::Print.error "You are not on the branch #{branch_name}. Please switch to the branch #{branch_name} and try again."
          exit 1
        end

        if pr_number.nil?
          Interfaces::Print.error "Could not determine PR number from the branch name."
          exit 1
        end

        plan_file = Interfaces::Repo.plan_file(issue_number)

        api_token = Interfaces::Ci.api_token
        retry_count = 0

        # Get repository info
        repo_owner, = Interfaces::Shell.run_command('gh repo view --json owner -q .owner.login')
        repo_name, = Interfaces::Shell.run_command('gh repo view --json name -q .name')

        # Ensure tmp directory exists
        FileUtils.mkdir_p(Interfaces::Repo.tmp_dir)

        while retry_count < MAX_RETRIES
          Interfaces::Print.info "Iteration #{retry_count + 1}/#{MAX_RETRIES}"

          # Wait for build to complete
          if Interfaces::Ci.wait_for_build(pr_number, repo_owner, repo_name, api_token)
            Interfaces::Print.success "CircleCI build passed! Issue ##{issue_number} has been successfully solved."
            return true
          end

          # Build failed, get failure details
          Interfaces::Print.warning 'Build failed. Analyzing failures...'
          failure_details = Interfaces::Ci.build_failures(pr_number, repo_owner, repo_name, api_token) || 'Could not fetch failure details'

          Interfaces::Print.info 'Failure details:'
          puts failure_details

          retry_count += 1

          if retry_count >= MAX_RETRIES
            Interfaces::Print.error "Maximum retry count (#{MAX_RETRIES}) reached. Please fix the issues manually."
            exit 1
          end

          # Store the failure details in a new file for each iteration
          filename = Interfaces::Repo.failure_details_file(branch_name, retry_count)
          File.write(filename, failure_details)

          # Fix the issues
          Interfaces::Print.info "Attempting to fix the issues (attempt #{retry_count}/#{MAX_RETRIES})..."

          fix_instructions = <<~FIX_INSTRUCTIONS
            The CircleCI build for PR ##{pr_number} has failed. The failure details have been logged into the following file:

            #{filename}

            Do as follows:
            1. Review your original plan that you documented in the plan file: `#{plan_file}`
            2. Analyze the failures above
            3. Make the necessary changes to fix the issues
            4. Commit and push the changes to the PR branch
            5. After pushing, output "FIXES_PUSHED" so I know you've completed the fixes

            The PR branch is: `issue-#{issue_number}`
          FIX_INSTRUCTIONS

          # Pass fix instructions to claude code
          fix_output = Interfaces::Agent.run(fix_instructions)
          puts "FIX_OUTPUT: #{fix_output}"

          # Check if fixes were pushed
          if fix_output.include?('FIXES_PUSHED')
            Interfaces::Print.success 'Fixes have been pushed. Waiting before checking build status again...'
            sleep 60 # Wait a bit for CircleCI to pick up the new commit
          else
            Interfaces::Print.error 'Could not confirm that fixes were pushed. Please check manually.'
            exit 1
          end
        end

        Interfaces::Print.error "Failed to resolve CircleCI build issues after #{MAX_RETRIES} attempts"
        exit 1
      end
    end
  end
end
