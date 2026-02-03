# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Wralph::Run::ExecutePlan do
  describe '.run' do
    let(:issue_number) { '123' }
    let(:branch_name) { "issue-#{issue_number}" }
    let(:plan_file) { File.join('.wralph', 'plans', "plan_#{issue_number}.md") }
    let(:secrets_file) { File.join('.wralph', 'secrets.yaml') }

    before do
      # Mock git branch --show-current (can be overridden in specific tests)
      allow(Wralph::Interfaces::Shell).to receive(:run_command)
        .with('git branch --show-current')
        .and_return(['master', '', true])
    end

    context 'when plan file does not exist' do
      it 'fetches issue and executes based on issue content' do
        Dir.mktmpdir do |tmpdir|
          FileUtils.mkdir_p(File.join(tmpdir, '.git'))
          FileUtils.mkdir_p(File.join(tmpdir, '.wralph', 'plans'))

          # Mock git branch --show-current
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git branch --show-current')
            .and_return(['master', '', true])

          # Mock get_worktrees
          allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([])

          # Mock git rev-parse
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git rev-parse --show-toplevel')
            .and_return([tmpdir, '', true])

          # Mock switch_into_worktree
          allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree) do |branch, _options|
            # Stay in tmpdir for test
          end

          # Mock gh issue view to return issue content
          issue_content = "Title: Test Issue\nBody: This is a test issue\n"
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with("gh issue view #{issue_number}")
            .and_return([issue_content, '', true])

          # Mock Agent.run
          allow(Wralph::Interfaces::Agent).to receive(:run).and_return('PR Number: 456')

          # Mock IterateCI.run
          allow(Wralph::Run::IterateCI).to receive(:run)

          # Mock switch_into_worktree for switching back
          allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree).with('master')

          Dir.chdir(tmpdir) do
            described_class.run(issue_number)
          end

          # Verify that gh issue view was called
          expect(Wralph::Interfaces::Shell).to have_received(:run_command)
            .with("gh issue view #{issue_number}")
        end
      end

      it 'extracts PR number from Claude output with Pull Request Details section' do
        # Structure must include a numbered list (1. 2. 3.) before Pull Request Details so that
        # without the Pattern 2 fix, a fallback matches the list "1" and returns wrong PR number.
        claude_output = <<~OUTPUT
          Perfect! I have successfully executed the plan to solve issue #42. Here's a summary:

          ## Implementation Summary

          I've implemented the solution for issue #42 by adding a new feature to the API.

          ### Changes Made:

          1. **WidgetType** (\`lib/widgets/type.rb\`)
             - Added \`primary_tenant\` field

          2. **ApiResolver** (\`lib/api/resolver.rb\`)
             - Updated resolver to return tenant based on current user or invitation

          3. **Test Coverage** (\`spec/widgets/type_spec.rb\`)
             - Added test cases for logged-in users, invited users, and invalid tokens

          ### Pull Request Details:

          - **PR Number**: #19901
          - **PR URL**: https://some-url
          - **Base Branch**: staging
          - **Status**: Created and ready for review
        OUTPUT

        Dir.mktmpdir do |tmpdir|
          FileUtils.mkdir_p(File.join(tmpdir, '.git'))
          FileUtils.mkdir_p(File.join(tmpdir, '.wralph', 'plans'))

          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git branch --show-current')
            .and_return(['master', '', true])
          allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([])
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git rev-parse --show-toplevel')
            .and_return([tmpdir, '', true])
          allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree)
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with("gh issue view #{issue_number}")
            .and_return(["Title: Test\nBody: Body\n", '', true])

          allow(Wralph::Interfaces::Agent).to receive(:run).and_return(claude_output)
          allow(Wralph::Run::IterateCI).to receive(:run)

          Dir.chdir(tmpdir) do
            described_class.run(issue_number)
          end

          expect(Wralph::Run::IterateCI).to have_received(:run).with(issue_number, '19901')
        end
      end

      it 'exits with error if issue fetch fails' do
        Dir.mktmpdir do |tmpdir|
          FileUtils.mkdir_p(File.join(tmpdir, '.git'))
          FileUtils.mkdir_p(File.join(tmpdir, '.wralph', 'plans'))

          # Mock git branch --show-current
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git branch --show-current')
            .and_return(['master', '', true])

          # Mock get_worktrees
          allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([])

          # Mock git rev-parse
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git rev-parse --show-toplevel')
            .and_return([tmpdir, '', true])

          # Mock switch_into_worktree
          allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree) do |branch, _options|
            # Stay in tmpdir for test
          end

          # Mock gh issue view to fail
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with("gh issue view #{issue_number}")
            .and_return(['', 'Issue not found', false])

          Dir.chdir(tmpdir) do
            expect { described_class.run(issue_number) }.to raise_error(SystemExit) do |error|
              expect(error.status).to eq(1)
            end
          end
        end
      end
    end

    context 'when creating a new worktree' do
      it 'copies entire .wralph directory from main repo to worktree' do
        Dir.mktmpdir do |main_repo|
          Dir.mktmpdir do |worktree_path|
            # Setup main repo with .wralph directory containing multiple files
            FileUtils.mkdir_p(File.join(main_repo, '.git'))
            FileUtils.mkdir_p(File.join(main_repo, '.wralph', 'plans'))
            main_plan_file = File.join(main_repo, plan_file)
            File.write(main_plan_file, '# Test plan')
            main_secrets_file = File.join(main_repo, secrets_file)
            File.write(main_secrets_file, "ci_api_token: test-token\n")
            main_config_file = File.join(main_repo, '.wralph', 'config.yaml')
            File.write(main_config_file, "objective_repository: github_issues\n")

            # Setup worktree directory structure (simulated)
            FileUtils.mkdir_p(File.join(worktree_path, '.wralph', 'plans'))
            worktree_plan_file = File.join(worktree_path, plan_file)
            File.write(worktree_plan_file, '# Test plan')
            worktree_secrets_file = File.join(worktree_path, secrets_file)
            worktree_config_file = File.join(worktree_path, '.wralph', 'config.yaml')

            # Mock git branch --show-current
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('git branch --show-current')
              .and_return(['master', '', true])

            # Mock git rev-parse to return main repo root
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('git rev-parse --show-toplevel')
              .and_return([main_repo, '', true])

            # Mock get_worktrees to return empty (no existing worktree)
            allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([])

            # Mock switch_into_worktree to simulate being in the worktree
            allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree) do |_branch, _options|
              # Change to worktree path
              Dir.chdir(worktree_path)
            end

            # Mock Repo methods to return worktree paths when in worktree
            allow(Wralph::Interfaces::Repo).to receive(:wralph_dir).and_return(File.join(worktree_path, '.wralph'))
            allow(Wralph::Interfaces::Repo).to receive(:secrets_file).and_return(worktree_secrets_file)
            allow(Wralph::Interfaces::Repo).to receive(:config_file).and_return(worktree_config_file)

            # Mock Agent.run to return PR info
            allow(Wralph::Interfaces::Agent).to receive(:run).and_return('PR Number: 456')

            # Mock IterateCI.run
            allow(Wralph::Run::IterateCI).to receive(:run)

            # Mock switch_into_worktree for switching back
            allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree).with('master') do
              Dir.chdir(main_repo)
            end

            Dir.chdir(worktree_path) do
              described_class.run(issue_number)
            end

            # Verify all .wralph files were copied to worktree
            expect(File.exist?(worktree_secrets_file)).to be true
            expect(File.read(worktree_secrets_file)).to eq("ci_api_token: test-token\n")
            expect(File.exist?(worktree_config_file)).to be true
            expect(File.read(worktree_config_file)).to eq("objective_repository: github_issues\n")
            # Verify plans directory was copied
            expect(File.exist?(File.join(worktree_path, '.wralph', 'plans'))).to be true
            expect(File.exist?(File.join(worktree_path, plan_file))).to be true
            expect(File.read(File.join(worktree_path, plan_file))).to eq('# Test plan')
          end
        end
      end

      it 'does not copy .wralph directory if it does not exist in main repo' do
        Dir.mktmpdir do |main_repo|
          Dir.mktmpdir do |worktree_path|
            # Setup main repo WITHOUT .wralph directory
            FileUtils.mkdir_p(File.join(main_repo, '.git'))

            # Setup worktree directory structure
            FileUtils.mkdir_p(File.join(worktree_path, '.wralph', 'plans'))
            worktree_plan_file = File.join(worktree_path, plan_file)
            File.write(worktree_plan_file, '# Test plan')
            worktree_secrets_file = File.join(worktree_path, secrets_file)

            # Mock git branch --show-current
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('git branch --show-current')
              .and_return(['master', '', true])

            # Mock git rev-parse to return main repo root
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('git rev-parse --show-toplevel')
              .and_return([main_repo, '', true])

            # Mock get_worktrees
            allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([])

            # Mock switch_into_worktree
            allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree) do |_branch, _options|
              Dir.chdir(worktree_path)
            end

            # Mock Repo methods
            allow(Wralph::Interfaces::Repo).to receive(:wralph_dir).and_return(File.join(worktree_path, '.wralph'))
            allow(Wralph::Interfaces::Repo).to receive(:secrets_file).and_return(worktree_secrets_file)

            # Mock Agent.run
            allow(Wralph::Interfaces::Agent).to receive(:run).and_return('PR Number: 456')

            # Mock IterateCI.run
            allow(Wralph::Run::IterateCI).to receive(:run)

            # Mock switch_into_worktree for switching back
            allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree).with('master') do
              Dir.chdir(main_repo)
            end

            Dir.chdir(worktree_path) do
              # Should not raise an error even though .wralph doesn't exist in main repo
              expect { described_class.run(issue_number) }.not_to raise_error
            end

            # Verify .wralph directory was NOT copied to worktree (only the pre-existing structure remains)
            # The worktree already had .wralph/plans from setup, but secrets.yaml should not exist
            expect(File.exist?(worktree_secrets_file)).to be false
          end
        end
      end
    end

    context 'when worktree already exists' do
      it 'does not copy .wralph directory' do
        Dir.mktmpdir do |tmpdir|
          FileUtils.mkdir_p(File.join(tmpdir, '.git'))

          # Create .wralph/plans directory and plan file
          FileUtils.mkdir_p(File.join(tmpdir, '.wralph', 'plans'))
          File.write(File.join(tmpdir, plan_file), '# Test plan')

          # Create secrets.yaml in main repo
          FileUtils.mkdir_p(File.join(tmpdir, '.wralph'))
          File.write(File.join(tmpdir, secrets_file), "ci_api_token: main-token\n")

          # Mock git branch --show-current
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git branch --show-current')
            .and_return(['master', '', true])

          # Mock get_worktrees to return existing worktree
          allow(Wralph::Interfaces::Shell).to receive(:get_worktrees)
            .and_return([{'branch' => branch_name, 'path' => tmpdir}])

          # Mock switch_into_worktree (should be called but not copy secrets)
          allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree) do |branch, _options|
            expect(branch).to eq(branch_name)
          end

          # Mock Agent.run
          allow(Wralph::Interfaces::Agent).to receive(:run).and_return('PR Number: 456')

          # Mock IterateCI.run
          allow(Wralph::Run::IterateCI).to receive(:run)

          # Mock switch_into_worktree for switching back
          allow(Wralph::Interfaces::Shell).to receive(:switch_into_worktree).with('master')

          Dir.chdir(tmpdir) do
            # Should not call git rev-parse (which would be for getting main repo root for copying)
            expect(Wralph::Interfaces::Shell).not_to receive(:run_command)
              .with('git rev-parse --show-toplevel')

            described_class.run(issue_number)
          end
        end
      end
    end
  end
end
