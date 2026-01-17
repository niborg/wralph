# frozen_string_literal: true

require 'fileutils'
require_relative '../interfaces/repo'
require_relative '../interfaces/print'
require_relative '../interfaces/shell'
require_relative '../interfaces/agent'
require_relative 'init'
require_relative 'execute_plan'

module Nitl
  module Run
    module Plan
      def self.run(issue_number)
        Init.ensure_initialized!

        plan_file = Interfaces::Repo.plan_file(issue_number)
        branch_name = "issue-#{issue_number}".freeze

        # Ensure plans directory exists
        FileUtils.mkdir_p(Interfaces::Repo.plans_dir)

        # Check if GitHub CLI is authenticated
        _, _, success = Interfaces::Shell.run_command('gh auth status')
        unless success
          Interfaces::Print.error 'GitHub CLI is not authenticated. Please run \'gh auth login\''
          exit 1
        end

        # Check for uncommitted changes
        _, _, success = Interfaces::Shell.run_command('git diff-index --quiet HEAD --')
        unless success
          Interfaces::Print.warning 'You have uncommitted changes. The script will create a new branch, but consider committing or stashing your changes first.'
          Interfaces::Shell.ask_user_to_continue('Continue anyway? (y/N) ')
        end

        # Fetch issue details to verify it exists
        Interfaces::Print.info "Fetching GitHub issue ##{issue_number}..."
        _, _, success = Interfaces::Shell.run_command("gh issue view #{issue_number}")
        unless success
          Interfaces::Print.error "Issue ##{issue_number} not found or not accessible"
          exit 1
        end

        # Check if branch already exists (locally or remotely)
        Interfaces::Print.info "Checking if branch '#{branch_name}' already exists..."
        _, _, success = Interfaces::Shell.run_command("git show-ref --verify --quiet refs/heads/#{branch_name}")
        if success
          Interfaces::Print.error "Branch '#{branch_name}' already exists locally. Please delete it first."
          exit 1
        end

        stdout, = Interfaces::Shell.run_command("git ls-remote --heads origin #{branch_name}")
        if stdout.include?(branch_name)
          Interfaces::Print.error "Branch '#{branch_name}' already exists on remote. Please delete it first."
          exit 1
        end

        Interfaces::Print.success "Branch '#{branch_name}' does not exist locally or remotely. Proceeding..."

        # Main workflow
        Interfaces::Print.info "Starting workflow to solve GitHub issue ##{issue_number}"

        # Step 1: Create initial plan and execute
        Interfaces::Print.info 'Step 1: Creating plan and executing solution...'

        instructions_template = <<~INSTRUCTIONS
          I need you to make a plan to solve GitHub issue ##{issue_number}. You are not to make any code changes. Instead, here's what I need you to do:

          1. First, read the GitHub issue using the gh CLI:
             `gh issue view #{issue_number}`

          2. Create a detailed plan for solving the issue. Write your thinking and plan in a markdown file at:
             `#{plan_file}`

           The plan should include:
           - Analysis of the issue.
           - Approach to solving it.
           - Test cases that should be written to verify the solution.
           - Steps you'll take.
           - Any potential risks or considerations.
           - A list of questions for any clarifications you need to ask the user. If you do not need any clarifications, you can say "No questions needed".
        INSTRUCTIONS

        # Run claude code with instructions
        Interfaces::Print.info "Running Claude Code to create a plan to solve issue ##{issue_number}..."
        claude_output = Interfaces::Agent.run(instructions_template)
        puts "CLAUDE_OUTPUT: #{claude_output}"

        # Check if the plan file was created
        unless File.exist?(plan_file)
          Interfaces::Print.error "Plan file '#{plan_file}' was not created. Please check the Claude Code output manually."
          Interfaces::Print.error "Output: #{claude_output}"
          exit 1
        end

        Interfaces::Print.success "Plan file '#{plan_file}' was created. Please review it, answering any questions Claude has asked."
        Interfaces::Shell.ask_user_to_continue('When you are ready to proceed, answer "y" to continue (y/N) ')

        # Execute the plan
        ExecutePlan.run(issue_number)
      end
    end
  end
end
