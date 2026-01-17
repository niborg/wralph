#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'utilities'

print_error "Usage: #{$0} <github_issue_number>" if ARGV.empty?

ISSUE_NUMBER = get_issue_from_command_line
PLANS_DIR = 'plans'
PLAN_FILE = "#{PLANS_DIR}/plan_gh_issue_no_#{ISSUE_NUMBER}.md".freeze
BRANCH_NAME = "issue-#{ISSUE_NUMBER}".freeze
MAX_RETRIES = 10

if !File.exist?(PLAN_FILE)
  print_error "Plan file '#{PLAN_FILE}' not found. Please create a plan first."
  exit 1
end

error_unless_tools_installed

current_branch = `git branch --show-current`.strip # To switch back later
switch_into_worktree(BRANCH_NAME)

execution_instructions = <<~EXECUTION_INSTRUCTIONS
  You previously created a plan to solve GitHub issue ##{ISSUE_NUMBER}. You can find the plan in the file: `#{PLAN_FILE}`. You have been placed in a git worktree for the branch `#{BRANCH_NAME}`.

  Do as follows:

  1. Execute your plan:
     - Make the necessary changes to solve the issue
     - Commit your changes (including the plan) with a descriptive message that references the issue
     - Push the branch to GitHub
     - Create a pull request, referencing the issue in the body like "Fixes ##{ISSUE_NUMBER}"

  2. After creating the PR, output the PR number and its URL so I can track it.

  Please proceed with these steps.
EXECUTION_INSTRUCTIONS

# Run claude code with instructions
print_info "Running Claude Code to execute the plan #{PLAN_FILE}..."
claude_output = run_claude(execution_instructions)
puts "CLAUDE_OUTPUT: #{claude_output}"

# Extract PR number from output (look for patterns like "PR #123", "**PR #123**", or "Pull Request #123")
# Try multiple patterns in order of specificity to avoid false matches
pr_number = nil

# Pattern 1: Look for PR in URL format (most reliable and unambiguous)
# Matches: https://github.com/owner/repo/pull/774
print_info "Extracting PR number from output by looking for the PR URL pattern..."
pr_number = claude_output.match(%r{github\.com/[^/\s]+/[^/\s]+/pull/(\d+)}i)&.[](1)

# Pattern 2: Look for "PR Number:" followed by optional markdown formatting and the number
# This handles formats like "PR Number: **#774**" or "PR Number: #774"
if pr_number.nil?
  # Match "PR Number:" followed by optional whitespace, optional markdown bold, optional #, then digits
  print_warning "Extracting PR number from output by looking for the PR Number pattern..."
  pr_number = claude_output.match(/PR\s+Number\s*:\s*(?:\*\*)?#?(\d+)/i)&.[](1)
end

# Pattern 3: Look for "PR #" or "Pull Request #" at start of line or after heading markers
if pr_number.nil?
  print_warning "Extracting PR number from output by looking for the PR # pattern..."
  pr_number = claude_output.match(/(?:^|\n|###\s+)[^\n]*(?:PR|Pull Request)[:\s]+(?:\*\*)?#?(\d+)/i)&.[](1)
end

# Pattern 4: Fallback to simple pattern but exclude "Found PR" patterns
if pr_number.nil?
  # Match PR but not if preceded by "Found" or similar words
  print_warning "Extracting PR number from output by looking for the PR pattern..."
  pr_number = claude_output.match(/(?<!Found\s)(?:PR|Pull Request)[:\s]+(?:\*\*)?#?(\d+)/i)&.[](1)
end

# Pattern 5: Last resort - any PR pattern (but this might match false positives)
if pr_number.nil?
  print_warning "Extracting PR number from output by looking for the any PR pattern..."
  pr_number = claude_output.match(/(?:PR|Pull Request|pull request)[^0-9]*#?(\d+)/i)&.[](1)
end

if pr_number.nil?
  # Try to find PR by branch name
  print_warning 'PR number not found in output, searching by branch name...'
  stdout, = run_command("gh pr list --head #{BRANCH_NAME} --json number -q '.[0].number'")
  pr_number = stdout.strip
  pr_number = nil if pr_number.empty? || pr_number == 'null'
end

if pr_number.nil?
  print_error 'Could not determine PR number. Please check the Claude Code output manually.'
  print_error "Output: #{claude_output}"
end

print_success "Found PR ##{pr_number}"
print_info 'Proceeding to monitor CircleCI build status...'

# Step 2: Monitor CircleCI build and fix if needed
system(File.join(__dir__, 'iterate_with_ci_results.rb'), ISSUE_NUMBER, pr_number)

switch_into_worktree(current_branch)
