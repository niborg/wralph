# frozen_string_literal: true

require_relative '../interfaces/repo'
require_relative '../interfaces/print'
require_relative '../interfaces/shell'
require_relative '../interfaces/agent'
require_relative '../interfaces/objective_repository'
require_relative '../utils'
require_relative '../config'
require_relative 'iterate_ci'

module Wralph
  module Run
    module ExecutePlan
      def self.run(issue_number)
        plan_file = Interfaces::Repo.plan_file(issue_number)
        plan_exists = File.exist?(plan_file)

        branch_name = Interfaces::Repo.branch_name(issue_number)
        stdout, = Interfaces::Shell.run_command('git branch --show-current')
        current_branch = stdout.strip

        # Check if worktree already exists, if not, create it and copy .wralph directory
        worktrees = Interfaces::Shell.get_worktrees
        worktree_exists = worktrees.any? { |wt| wt['branch'] == branch_name }

        if !worktree_exists
          # Get the main repo root before creating worktree (in case we're already in a worktree)
          # Use git rev-parse to reliably get the main repo root even from within a worktree
          stdout, _, success = Interfaces::Shell.run_command('git rev-parse --show-toplevel')
          main_repo_root = success && !stdout.empty? ? stdout.strip : Interfaces::Repo.repo_root
          main_wralph_dir = File.join(main_repo_root, '.wralph')

          # Create the worktree
          Interfaces::Shell.switch_into_worktree(branch_name)

          # Copy entire .wralph directory from main repo to the new worktree
          if Dir.exist?(main_wralph_dir)
            require 'fileutils'
            worktree_wralph_dir = Interfaces::Repo.wralph_dir

            # Only copy if source and destination are different (should always be true in real usage)
            main_wralph_expanded = File.expand_path(main_wralph_dir)
            worktree_wralph_expanded = File.expand_path(worktree_wralph_dir)

            if main_wralph_expanded != worktree_wralph_expanded
              FileUtils.mkdir_p(worktree_wralph_dir)
              # Copy all contents from main .wralph to worktree .wralph
              Dir.glob(File.join(main_wralph_dir, '*'), File::FNM_DOTMATCH).each do |item|
                next if ['.', '..'].include?(File.basename(item))

                dest_item = File.join(worktree_wralph_dir, File.basename(item))
                # Skip if source and destination are the same (can happen in tests)
                item_expanded = File.expand_path(item)
                dest_item_expanded = File.expand_path(dest_item)
                next if item_expanded == dest_item_expanded
                # Skip if destination is inside source (would cause recursive copy error)
                next if dest_item_expanded.start_with?(item_expanded + File::SEPARATOR)

                begin
                  FileUtils.cp_r(item, dest_item)
                rescue ArgumentError => e
                  # Handle edge case where source and dest are the same (can happen in tests)
                  next if e.message.include?('cannot copy') && e.message.include?('to itself')

                  raise
                end
              end
            end
          end
        else
          Interfaces::Shell.switch_into_worktree(branch_name)
        end

        # Build execution instructions based on whether plan exists
        config = Config.load

        if plan_exists
          prompt_template = config.prompts&.execute_with_plan
          execution_instructions = Utils.prompt_sub(
            prompt_template,
            {
              issue_number: issue_number,
              plan_file: plan_file,
              branch_name: branch_name
            }
          )
          Interfaces::Print.info "Running agent harness to execute the plan #{plan_file}..."
        else
          # Fetch issue content
          Interfaces::Print.info "No plan found. Fetching issue ##{issue_number}..."
          begin
            objective_file = Interfaces::ObjectiveRepository.download!(issue_number)
            File.read(objective_file)
          rescue StandardError => e
            Interfaces::Print.error "Failed to fetch objective ##{issue_number}: #{e.message}"
            exit 1
          end

          prompt_template = config.prompts&.execute_without_plan
          execution_instructions = Utils.prompt_sub(
            prompt_template,
            {
              issue_number: issue_number,
              objective_file: objective_file,
              branch_name: branch_name
            }
          )
          Interfaces::Print.info "Running agent harness to solve objective ##{issue_number}..."
        end

        # Run agent harness with instructions
        agent_output = Interfaces::Agent.run(execution_instructions)
        puts "AGENT_OUTPUT: #{agent_output}"

        # Extract PR number from output (look for patterns like "PR #123", "**PR #123**", or "Pull Request #123")
        # Try multiple patterns in order of specificity to avoid false matches

        # Pattern 1: Look for PR in URL format (most reliable and unambiguous)
        # Matches: .../owner/repo/pull/774 (any host, e.g. github.com or GHE)
        Interfaces::Print.info 'Extracting PR number from output by looking for the PR URL pattern...'
        pr_number = agent_output.match(%r{/[^/\s]+/[^/\s]+/pull/(\d+)}i)&.[](1)

        # Pattern 2: Look for "PR Number:" followed by optional markdown formatting and the number
        # Handles "PR Number: #774", "**PR Number**: #19901", "PR Number: **#774**"
        if pr_number.nil?
          # Allow optional ** around "Number" (e.g. "- **PR Number**: #19901") and after colon
          Interfaces::Print.warning 'Extracting PR number from output by looking for the PR Number pattern...'
          pr_number = agent_output.match(/PR\s+Number\s*(?:\*\*)?\s*:\s*(?:\*\*)?#?(\d+)/i)&.[](1)
        end

        # Pattern 3: Look for "PR #" or "Pull Request #" at start of line or after heading markers
        if pr_number.nil?
          Interfaces::Print.warning 'Extracting PR number from output by looking for the PR # pattern...'
          pr_number = agent_output.match(/(?:^|\n|###\s+)[^\n]*(?:PR|Pull Request)[:\s]+(?:\*\*)?#?(\d+)/i)&.[](1)
        end

        # Pattern 4: Fallback to simple pattern but exclude "Found PR" patterns
        if pr_number.nil?
          # Match PR but not if preceded by "Found" or similar words
          Interfaces::Print.warning 'Extracting PR number from output by looking for the PR pattern...'
          pr_number = agent_output.match(/(?<!Found\s)(?:PR|Pull Request)[:\s]+(?:\*\*)?#?(\d+)/i)&.[](1)
        end

        # Pattern 5: Last resort - any PR pattern (but this might match false positives)
        if pr_number.nil?
          Interfaces::Print.warning 'Extracting PR number from output by looking for the any PR pattern...'
          pr_number = agent_output.match(/(?:PR|Pull Request|pull request)[^0-9]*#?(\d+)/i)&.[](1)
        end

        if pr_number.nil?
          # Try to find PR by branch name
          Interfaces::Print.warning 'PR number not found in output, searching by branch name...'
          pr_number = Interfaces::Repo.get_pr_from_branch_name(branch_name)
        end

        if pr_number.nil?
          Interfaces::Print.error 'Could not determine PR number. Please check the agent output manually.'
          Interfaces::Print.error "Output: #{agent_output}"
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
