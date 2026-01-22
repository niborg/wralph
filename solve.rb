#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'tempfile'
require 'fileutils'
require 'shellwords'

require_relative 'utilities'

ISSUE_NUMBER = get_issue_from_command_line
PLANS_DIR = 'plans'
PLAN_FILE = "#{PLANS_DIR}/plan_gh_issue_no_#{ISSUE_NUMBER}.md".freeze
BRANCH_NAME = "issue-#{ISSUE_NUMBER}".freeze

# Create plans directory if it doesn't exist
FileUtils.mkdir_p(PLANS_DIR)

# Load environment variables from .env file if it exists
ENV = load_environment_variables
if ENV.empty?
  print_warning '.env file not found. Make sure CIRCLE_CI_API_TOKEN is set.'
else
  print_success 'Loaded environment variables from .env'
end

# Check if required tools are installed
error_unless_tools_installed

# Check if GitHub CLI is authenticated
_, _, success = run_command('gh auth status')
print_error 'GitHub CLI is not authenticated. Please run \'gh auth login\'' unless success

# Check for uncommitted changes
_, _, success = run_command('git diff-index --quiet HEAD --')
unless success
  print_warning 'You have uncommitted changes. The script will create a new branch, but consider committing or stashing your changes first.'
  ask_user_to_continue('Continue anyway? (y/N) ')
end

# Fetch issue details to verify it exists
print_info "Fetching GitHub issue ##{ISSUE_NUMBER}..."
_, _, success = run_command("gh issue view #{ISSUE_NUMBER}")
print_error "Issue ##{ISSUE_NUMBER} not found or not accessible" unless success

# Check if branch already exists (locally or remotely)
print_info "Checking if branch '#{BRANCH_NAME}' already exists..."
_, _, success = run_command("git show-ref --verify --quiet refs/heads/#{BRANCH_NAME}")
print_error "Branch '#{BRANCH_NAME}' already exists locally. Please delete it with scripts/ai/delete_solution.rb." if success

stdout, = run_command("git ls-remote --heads origin #{BRANCH_NAME}")
print_error "Branch '#{BRANCH_NAME}' already exists on remote. Please delete it with scripts/ai/delete_solution.rb." if stdout.include?(BRANCH_NAME)

print_success "Branch '#{BRANCH_NAME}' does not exist locally or remotely. Proceeding..."

# Main workflow
print_info "Starting workflow to solve GitHub issue ##{ISSUE_NUMBER}"

# Step 1: Create initial plan and execute
print_info 'Step 1: Creating plan and executing solution...'

instructions_template = <<~INSTRUCTIONS
  I need you to make a plan tosolve GitHub issue ##{ISSUE_NUMBER}. You are not to make any code changes. Instead, here's what I need you to do:

  1. First, read the GitHub issue using the gh CLI:
     `gh issue view #{ISSUE_NUMBER}`

  2. Create a detailed plan for solving the issue. Write your thinking and plan in a markdown file at:
     `#{PLAN_FILE}`

     The plan should include:
     - Analysis of the issue.
     - Approach to solving it.
     - Test cases that should be written to verify the solution.
     - Steps you'll take.
     - Any potential risks or considerations.
     - A list of questions for any clarifications you need to ask the user. If you do not need any clarifications, you can say "No questions needed".
INSTRUCTIONS

# Run claude code with instructions
print_info "Running Claude Code to create a plan to solve issue ##{ISSUE_NUMBER}..."
claude_output = run_claude(instructions_template)
puts "CLAUDE_OUTPUT: #{claude_output}"

# Check if the plan file was created
unless File.exist?(PLAN_FILE)
  print_error "Plan file '#{PLAN_FILE}' was not created. Please check the Claude Code output manually."
  print_error "Output: #{claude_output}"
  exit 1
end

print_success "Plan file '#{PLAN_FILE}' was created. Please review it, answering any questions Claude has asked."
ask_user_to_continue('When you are ready to proceed, answer "y" to continue (y/N) ')

success = system(File.join(__dir__, 'execute_plan.rb'), ISSUE_NUMBER)
print_error "execute_plan.rb failed with exit code #{$?.exitstatus}" unless success
