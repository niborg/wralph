#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'utilities'

print_error "Usage: #{$0} <github_issue_number>" if ARGV.empty?

ISSUE_NUMBER = ARGV[0]
PLANS_DIR = 'plans'
BRANCH_NAME = "issue-#{ISSUE_NUMBER}".freeze

_, _, success = run_command("git branch -D #{BRANCH_NAME}")
if success
  print_info "Deleted branch '#{BRANCH_NAME}' locally"
else
  print_warning "Branch '#{BRANCH_NAME}' not found" unless success
end

_, _, success = run_command("git push origin --delete #{BRANCH_NAME}")
if success
  print_info "Deleted branch '#{BRANCH_NAME}' on remote"
else
  print_warning "Branch '#{BRANCH_NAME}' not found on remote"
end

_, _, success = run_command("wt remove #{BRANCH_NAME}")
if success
  print_info "Removed worktree for branch '#{BRANCH_NAME}'"
else
  print_warning "Worktree for branch '#{BRANCH_NAME}' not found"
end
