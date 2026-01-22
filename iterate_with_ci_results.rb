#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'utilities'

ISSUE_NUMBER = get_issue_from_command_line
BRANCH_NAME = "issue-#{ISSUE_NUMBER}".freeze
PR_NUMBER = ARGV[1] || begin
  stdout, = run_command("gh pr list --head #{BRANCH_NAME} --json number -q '.[0].number'")
  pr_number = stdout.strip
  pr_number.empty? || pr_number == 'null' ? nil : pr_number
end

current_branch = `git branch --show-current`.strip
if current_branch != BRANCH_NAME
  print_error "You are not on the branch #{BRANCH_NAME}. Please switch to the branch #{BRANCH_NAME} and try again."
  exit 1
end

if PR_NUMBER.nil?
  print_error "Could not determine PR number from the branch name."
  exit 1
end

MAX_RETRIES = 10
PLANS_DIR = 'plans'
PLAN_FILE = "#{PLANS_DIR}/plan_gh_issue_no_#{ISSUE_NUMBER}.md".freeze

ENV = load_environment_variables
if ENV.empty?
  print_warning '.env file not found. Make sure CIRCLE_CI_API_TOKEN is set.'
else
  print_success 'Loaded environment variables from .env'
end

api_token = ENV['CIRCLE_CI_API_TOKEN']
retry_count = 0

# Get repository info
repo_owner, = run_command('gh repo view --json owner -q .owner.login')
repo_name, = run_command('gh repo view --json name -q .name')

while retry_count < MAX_RETRIES
  print_info "Iteration #{retry_count + 1}/#{MAX_RETRIES}"

  # Wait for build to complete
  if wait_for_circleci_build(pr_number, repo_owner, repo_name, api_token)
    print_success "CircleCI build passed! Issue ##{ISSUE_NUMBER} has been successfully solved."
    exit 0
  end

  # Build failed, get failure details
  print_warning 'Build failed. Analyzing failures...'
  failure_details = get_circleci_build_failures(pr_number, repo_owner, repo_name, api_token) || 'Could not fetch failure details'

  print_info 'Failure details:'
  puts failure_details

  retry_count += 1

  print_error "Maximum retry count (#{MAX_RETRIES}) reached. Please fix the issues manually." if retry_count >= MAX_RETRIES

  # Store the failure details in a new file for each iteration
  filename = "tmp/#{BRANCH_NAME}_failure_details_#{retry_count}_#{retry_count}.txt"
  File.write(filename, failure_details)

  # Fix the issues
  print_info "Attempting to fix the issues (attempt #{retry_count}/#{MAX_RETRIES})..."

  fix_instructions = <<~FIX_INSTRUCTIONS
    The CircleCI build for PR ##{pr_number} has failed. The failure details have been logged into the following file:

    #{filename}

    Do as follows:
    1. Review your original plan that you documented in the plan file: `#{PLAN_FILE}`
    2. Analyze the failures above
    3. Make the necessary changes to fix the issues
    4. Commit and push the changes to the PR branch
    5. After pushing, output "FIXES_PUSHED" so I know you've completed the fixes

    The PR branch is: `issue-#{ISSUE_NUMBER}`
  FIX_INSTRUCTIONS

  # Pass fix instructions to claude code
  fix_output = run_claude(fix_instructions)
  puts "FIX_OUTPUT: #{fix_output}"

  # Check if fixes were pushed
  if fix_output.include?('FIXES_PUSHED')
    print_success 'Fixes have been pushed. Waiting before checking build status again...'
    sleep 60 # Wait a bit for CircleCI to pick up the new commit
  else
    print_error 'Could not confirm that fixes were pushed. Please check manually.'
  end
end

print_error "Failed to resolve CircleCI build issues after #{MAX_RETRIES} attempts"
exit 1
