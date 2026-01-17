#!/usr/bin/env ruby
# frozen_string_literal: true

require 'reline'
require_relative 'utilities'

ISSUE_NUMBER = get_issue_from_command_line
PLANS_DIR = 'plans'
PLAN_FILE = "#{PLANS_DIR}/plan_gh_issue_no_#{ISSUE_NUMBER}.md".freeze
BRANCH_NAME = "issue-#{ISSUE_NUMBER}".freeze

error_unless_tools_installed

current_branch = `git branch --show-current`.strip
switch_into_worktree(BRANCH_NAME, create_if_not_exists: false)

# Check that the Pull Request is open
stdout, = run_command("gh pr view #{BRANCH_NAME} --json state -q .state")
if stdout.strip != 'OPEN'
  print_error "Pull Request #{ISSUE_NUMBER} is not open. Please open it and try again."
  exit 1
end

# Get input from user on changes to make to the Pull Request
print_info "Please review the changes to the Pull Request and provide feedback on what changes to make."
print_info "  - Press Enter for a new line"
print_info "  - Press Enter three times to submit"

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
changes = changes.chomp

# Ask Claude to make the changes
print_info "Asking Claude to evaluate your comments to the Pull Request..."
instructions = <<~INSTRUCTIONS
  Background: You previously created a plan (found in the file #{PLAN_FILE}) and executed changes into a Pull Request
  from the current branch (#{BRANCH_NAME}) to the git origin. You can compare this branch against master
  to see your proposed changes.

  The user has reviewed your Pull Request and requested the following changes:

  #{changes}

  Do as follows:
    1. Review your original plan that you documented in the plan file: `#{PLAN_FILE}`
    2. Analyze the code changes that you've made in this branch by comparing it to the master branch
    2. Review the user input
    3. Make the necessary changes address the issues raised by the user
    4. Commit and push the changes to the Pull Request branch
    5. After pushing, output "FIXES_PUSHED" so I know you've completed the fixes
INSTRUCTIONS

# Run claude code with instructions
claude_output = run_claude(instructions)
puts "CLAUDE_OUTPUT: #{claude_output}"

# Check if fixes were pushed
if claude_output.include?('FIXES_PUSHED')
  print_success 'Fixes have been pushed. Waiting before checking build status again...'
  sleep 60 # Wait a bit for CircleCI to pick up the new commit
else
  print_error 'Could not confirm that fixes were pushed. Please check manually.'
end

system(File.join(__dir__, 'iterate_with_ci_results.rb'), ISSUE_NUMBER)

switch_into_worktree(current_branch)
