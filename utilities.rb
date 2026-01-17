# frozen_string_literal: true

require 'json'
require 'open3'
require 'shellwords'

# Colors for output
module Colors
  RED = "\033[0;31m"
  GREEN = "\033[0;32m"
  YELLOW = "\033[1;33m"
  BLUE = "\033[0;34m"
  NC = "\033[0m" # No Color
end

# Helper methods for colored output
def print_info(msg)
  puts "#{Colors::BLUE}ℹ#{Colors::NC} #{msg}"
end

def print_success(msg)
  puts "#{Colors::GREEN}✓#{Colors::NC} #{msg}"
end

def print_warning(msg)
  puts "#{Colors::YELLOW}⚠#{Colors::NC} #{msg}"
end

def print_error(msg)
  puts "#{Colors::RED}✗#{Colors::NC} #{msg}"
  exit 1
end

# Check if a command exists
def command_exists?(cmd)
  system("which #{cmd} > /dev/null 2>&1")
end

# Run a command and return stdout, stderr, and status
def run_command(cmd, raise_on_error: false)
  stdout, stderr, status = Open3.capture3(cmd)
  raise "Command failed: #{cmd}\n#{stderr}" if raise_on_error && !status.success?

  [stdout.chomp, stderr.chomp, status.success?]
end

def get_issue_from_command_line
  print_error "Usage: #{$0} <github_issue_number>" if ARGV.empty?
  ARGV[0]
end

def get_worktrees
  json_output, = run_command("wt list --format=json")
  JSON.parse(json_output)
end

def switch_into_worktree(branch_name, create_if_not_exists: true)
  # Check if any entry matches the branch name
  worktree = get_worktrees.find { |wt| wt['branch'] == branch_name }
  if worktree
    success = system("wt switch #{worktree['branch']}")
    print_error "Failed to switch to branch #{branch_name}" unless success
  else
    if create_if_not_exists
      success = system("wt switch --create #{branch_name}")
      print_error "Failed to switch to branch #{branch_name}" unless success
      worktree = get_worktrees.find { |wt| wt['branch'] == branch_name }
    else
      print_error "Worktree for branch #{branch_name} not found. Use --create to create it."
      exit 1
    end
  end

  # Change the directory of the CURRENT Ruby process to the new worktree
  Dir.chdir(worktree['path'])
end


def error_unless_tools_installed
  required_tools = {
    'gh' => 'https://cli.github.com/',
    'claude' => 'https://code.claude.com/',
    'jq' => 'brew install jq on macOS',
    'curl' => 'usually pre-installed',
    'wt' => 'https://github.com/max-sixty/worktrunk'
  }

  required_tools.each do |tool, install_info|
    unless command_exists?(tool)
      print_error "#{tool} CLI is not installed. Please install it from #{install_info}"
    end
  end
end

def ask_user_to_continue(message = 'Continue? (y/N) ')
  print message
  response = $stdin.gets.chomp
  exit 1 unless response =~ /^[Yy]$/
end

def load_environment_variables
  return {} unless File.exist?('.env')

  File.readlines('.env').each_with_object({}) do |line, env|
    line.strip!
    next if line.empty? || line.start_with?('#')

    key, value = line.split('=', 2)
    env[key] = value if key && value
  end
end

def run_claude(instructions)
  claude_output, = run_command(
    "claude -p #{Shellwords.shellescape(instructions)} --dangerously-skip-permissions", raise_on_error: false
  )
  claude_output
end

# Function to get CircleCI build status for a PR
def get_circleci_build_status(pr_number, repo_owner, repo_name, api_token, verbose: true)
  unless api_token
    print_error 'CIRCLE_CI_API_TOKEN is not set in .env file'
    return nil
  end

  # Get the branch name from the PR
  branch_name, = run_command("gh pr view #{pr_number} --json headRefName -q .headRefName")
  branch_name.strip!
  print_info "Checking CircleCI build for branch: #{branch_name}" if verbose && $stderr.respond_to?(:puts)

  # Get the pipeline for this branch
  project_slug = "gh/#{repo_owner}/#{repo_name}"
  pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"

  stdout, _, success = run_command("curl -s -f -H 'Circle-Token: #{api_token}' '#{pipeline_url}'")
  unless success
    print_warning "No CircleCI pipeline found for branch #{branch_name}" if verbose
    return 'not_found'
  end

  begin
    pipeline_data = JSON.parse(stdout)
    pipeline_item = pipeline_data['items']&.first
    return 'not_found' unless pipeline_item

    pipeline_id = pipeline_item['id']
    pipeline_state = pipeline_item['state']

    print_info "Pipeline ID: #{pipeline_id}, State: #{pipeline_state}" if verbose

    return 'running' if %w[running pending].include?(pipeline_state)

    # Get workflow details to check if it succeeded
    workflow_url = "https://circleci.com/api/v2/pipeline/#{pipeline_id}/workflow"
    stdout, _, success = run_command("curl -s -f -H 'Circle-Token: #{api_token}' '#{workflow_url}'")
    unless success
      print_warning "No workflow found for pipeline #{pipeline_id}" if verbose
      return 'unknown'
    end

    workflow_data = JSON.parse(stdout)
    workflow_item = workflow_data['items']&.first
    unless workflow_item
      print_warning "No workflow found for pipeline #{pipeline_id}" if verbose
      return 'unknown'
    end

    workflow_status = workflow_item['status']&.strip
    print_info "Workflow status: #{workflow_status}" if verbose

    workflow_status
  rescue JSON::ParserError => e
    print_warning "Failed to parse JSON response: #{e.message}" if verbose
    'unknown'
  end
end

# Function to wait for CircleCI build to complete
def wait_for_circleci_build(pr_number, repo_owner, repo_name, api_token)
  max_wait_time = 3600 # 1 hour max wait
  wait_interval = 30   # Check every 30 seconds
  elapsed = 0

  print_info 'Waiting for CircleCI build to complete...'

  last_status = nil
  while elapsed < max_wait_time
    # Get status quietly first to check if it changed
    status = get_circleci_build_status(pr_number, repo_owner, repo_name, api_token, verbose: false)

    # If status hasn't changed since last check, just print a dot
    if last_status && last_status == status
      print '.'
      sleep wait_interval
      elapsed += wait_interval
      next
    end

    # Status changed (or first check) - get verbose output with pipeline/workflow details
    status = get_circleci_build_status(pr_number, repo_owner, repo_name, api_token, verbose: true)

    case status
    when 'success'
      print_success 'CircleCI build passed!'
      return true
    when 'failed', 'error', 'canceled', 'unauthorized'
      print_warning "CircleCI build failed with status: #{status}"
      return false
    when 'running', 'on_hold'
      print_info "Build still running... (elapsed: #{elapsed}s)"
    when 'not_found'
      print_warning 'Build not found yet, waiting...'
    else
      print_warning "Unknown build status: #{status}, waiting..."
    end
    sleep wait_interval
    elapsed += wait_interval
    last_status = status
  end

  print_error 'Timeout waiting for CircleCI build to complete'
  false
end

# Function to get CircleCI build failures
def get_circleci_build_failures(pr_number, repo_owner, repo_name, api_token)
  return 'CIRCLE_CI_API_TOKEN is not set' unless api_token

  # 1. Get branch name from PR
  branch_name, = run_command("gh pr view #{pr_number} --json headRefName -q .headRefName")
  branch_name.strip!

  # 2. Get the latest pipeline for that branch
  project_slug = "gh/#{repo_owner}/#{repo_name}"
  pipeline_url = "https://circleci.com/api/v2/project/#{project_slug}/pipeline?branch=#{branch_name}"
  stdout, _, success = run_command("curl -s -H 'Circle-Token: #{api_token}' '#{pipeline_url}'")
  return 'Could not fetch pipeline' unless success

  pipeline_id = JSON.parse(stdout)['items']&.first&.[]('id')
  return 'No pipeline found' unless pipeline_id

  # 3. Get the workflow ID
  workflow_url = "https://circleci.com/api/v2/pipeline/#{pipeline_id}/workflow"
  stdout, _, success = run_command("curl -s -H 'Circle-Token: #{api_token}' '#{workflow_url}'")
  workflow_id = JSON.parse(stdout)['items']&.first&.[]('id')
  return 'No workflow found' unless workflow_id

  # 4. Get jobs and filter for failures
  jobs_url = "https://circleci.com/api/v2/workflow/#{workflow_id}/job"
  stdout, _, success = run_command("curl -s -H 'Circle-Token: #{api_token}' '#{jobs_url}'")
  jobs_data = JSON.parse(stdout)

  failed_jobs = jobs_data['items']&.select { |j| %w[failed error].include?(j['status']) }
  return "All jobs passed for branch #{branch_name}." if failed_jobs.nil? || failed_jobs.empty?

  # 5. For each failed job, reach into v1.1 API to get the logs
  failed_jobs.map do |job|
    job_num = job['job_number']
    job_name = job['name']

    # We use v1.1 because v2 does not provide step-level output URLs
    v1_api_url = "https://circleci.com/api/v1.1/project/github/#{repo_owner}/#{repo_name}/#{job_num}"
    v1_stdout, _, v1_success = run_command("curl -s -H 'Circle-Token: #{api_token}' '#{v1_api_url}'")

    log_content = "Job: #{job_name} (##{job_num}) failed."

    if v1_success
      job_details = JSON.parse(v1_stdout)
      # Find the step that actually failed
      failed_step = job_details['steps']&.find { |s| s['actions'].any? { |a| a['failed'] } }

      if failed_step
        action = failed_step['actions'].find { |a| a['failed'] }
        output_url = action['output_url']

        if output_url
          # The output_url provides a JSON array of log lines
          raw_log_json, _, _ = run_command("curl -s '#{output_url}'")
          begin
            logs = JSON.parse(raw_log_json)
            # Join the last 30 lines of the log for context
            tail_logs = logs.map { |l| l['message'] }.last(30).join("\n")
            log_content += "\nFAILED STEP: #{failed_step['name']}\n\nLOG TAIL:\n#{tail_logs}"
          rescue
            log_content += "\n(Could not parse raw log output)"
          end
        end
      end
    end

    log_content
  end.join("\n\n" + "="*40 + "\n\n")
end
