# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Wralph::Run::SetConfig do
  describe '.run' do
    let(:issue_number) { '123' }
    let(:branch_name) { "issue-#{issue_number}" }

    context 'when called from within a worktree' do
      it 'exits with error' do
        Dir.mktmpdir do |tmpdir|
          FileUtils.mkdir_p(File.join(tmpdir, '.git'))
          FileUtils.mkdir_p(File.join(tmpdir, '.wralph'))

          # Mock git rev-parse to return a path (indicating we're in a git repo)
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git rev-parse --show-toplevel')
            .and_return([tmpdir, '', true])

          # Mock the worktree check to return true (we're in a worktree)
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('test -f "$(git rev-parse --git-dir)/commondir"')
            .and_return(['', '', true])

          # Mock Repo.repo_root
          allow(Wralph::Interfaces::Repo).to receive(:repo_root).and_return(tmpdir)

          # Mock Repo.branch_name
          allow(Wralph::Interfaces::Repo).to receive(:branch_name).with(issue_number).and_return(branch_name)

          Dir.chdir(tmpdir) do
            expect { described_class.run(issue_number) }.to raise_error(SystemExit) do |error|
              expect(error.status).to eq(1)
            end
          end
        end
      end
    end

    context 'when worktree does not exist for issue' do
      it 'exits with error' do
        Dir.mktmpdir do |tmpdir|
          FileUtils.mkdir_p(File.join(tmpdir, '.git'))
          FileUtils.mkdir_p(File.join(tmpdir, '.wralph'))

          # Mock git rev-parse
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('git rev-parse --show-toplevel')
            .and_return([tmpdir, '', true])

          # Mock the worktree check to return false (we're NOT in a worktree)
          allow(Wralph::Interfaces::Shell).to receive(:run_command)
            .with('test -f "$(git rev-parse --git-dir)/commondir"')
            .and_return(['', '', false])

          # Mock Repo methods
          allow(Wralph::Interfaces::Repo).to receive(:repo_root).and_return(tmpdir)
          allow(Wralph::Interfaces::Repo).to receive(:branch_name).with(issue_number).and_return(branch_name)

          # Mock get_worktrees to return empty (no worktrees exist)
          allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([])

          Dir.chdir(tmpdir) do
            expect { described_class.run(issue_number) }.to raise_error(SystemExit) do |error|
              expect(error.status).to eq(1)
            end
          end
        end
      end
    end

    context 'when .wralph directory does not exist in main repo' do
      it 'exits with error' do
        Dir.mktmpdir do |main_repo|
          Dir.mktmpdir do |worktree_path|
            FileUtils.mkdir_p(File.join(main_repo, '.git'))
            # Note: NOT creating .wralph directory

            # Mock Init.ensure_initialized! to pass (simulate wralph is initialized)
            allow(Wralph::Run::Init).to receive(:ensure_initialized!)

            # Mock git rev-parse
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('git rev-parse --show-toplevel')
              .and_return([main_repo, '', true])

            # Mock the worktree check to return false
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('test -f "$(git rev-parse --git-dir)/commondir"')
              .and_return(['', '', false])

            # Mock Repo methods
            allow(Wralph::Interfaces::Repo).to receive(:repo_root).and_return(main_repo)
            allow(Wralph::Interfaces::Repo).to receive(:branch_name).with(issue_number).and_return(branch_name)
            allow(Wralph::Interfaces::Repo).to receive(:wralph_dir).and_return(File.join(main_repo, '.wralph'))

            # Mock get_worktrees to return a worktree
            allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([
              {'branch' => branch_name, 'path' => worktree_path}
            ])

            Dir.chdir(main_repo) do
              expect { described_class.run(issue_number) }.to raise_error(SystemExit) do |error|
                expect(error.status).to eq(1)
              end
            end
          end
        end
      end
    end

    context 'when all conditions are met' do
      it 'successfully copies .wralph contents to worktree' do
        Dir.mktmpdir do |main_repo|
          Dir.mktmpdir do |worktree_path|
            # Setup main repo with .wralph directory containing multiple files
            FileUtils.mkdir_p(File.join(main_repo, '.git'))
            FileUtils.mkdir_p(File.join(main_repo, '.wralph', 'plans'))

            # Create various files in .wralph
            main_secrets_file = File.join(main_repo, '.wralph', 'secrets.yaml')
            File.write(main_secrets_file, "ci_api_token: test-token\n")

            main_config_file = File.join(main_repo, '.wralph', 'config.yaml')
            File.write(main_config_file, "objective_repository: github_issues\n")

            main_plan_file = File.join(main_repo, '.wralph', 'plans', 'plan_123.md')
            File.write(main_plan_file, "# Test plan\n")

            # Setup worktree directory structure
            FileUtils.mkdir_p(File.join(worktree_path, '.git'))
            FileUtils.mkdir_p(File.join(worktree_path, '.wralph'))

            # Mock git rev-parse
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('git rev-parse --show-toplevel')
              .and_return([main_repo, '', true])

            # Mock the worktree check to return false (we're NOT in a worktree)
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('test -f "$(git rev-parse --git-dir)/commondir"')
              .and_return(['', '', false])

            # Mock Repo methods
            allow(Wralph::Interfaces::Repo).to receive(:repo_root).and_return(main_repo)
            allow(Wralph::Interfaces::Repo).to receive(:branch_name).with(issue_number).and_return(branch_name)
            allow(Wralph::Interfaces::Repo).to receive(:wralph_dir).and_return(File.join(main_repo, '.wralph'))

            # Mock get_worktrees to return a worktree
            allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([
              {'branch' => branch_name, 'path' => worktree_path}
            ])

            Dir.chdir(main_repo) do
              described_class.run(issue_number)
            end

            # Verify all .wralph files were copied to worktree
            worktree_secrets_file = File.join(worktree_path, '.wralph', 'secrets.yaml')
            expect(File.exist?(worktree_secrets_file)).to be true
            expect(File.read(worktree_secrets_file)).to eq("ci_api_token: test-token\n")

            worktree_config_file = File.join(worktree_path, '.wralph', 'config.yaml')
            expect(File.exist?(worktree_config_file)).to be true
            expect(File.read(worktree_config_file)).to eq("objective_repository: github_issues\n")

            worktree_plan_file = File.join(worktree_path, '.wralph', 'plans', 'plan_123.md')
            expect(File.exist?(worktree_plan_file)).to be true
            expect(File.read(worktree_plan_file)).to eq("# Test plan\n")
          end
        end
      end

      it 'overwrites existing .wralph contents in worktree' do
        Dir.mktmpdir do |main_repo|
          Dir.mktmpdir do |worktree_path|
            # Setup main repo with .wralph directory
            FileUtils.mkdir_p(File.join(main_repo, '.git'))
            FileUtils.mkdir_p(File.join(main_repo, '.wralph'))

            main_secrets_file = File.join(main_repo, '.wralph', 'secrets.yaml')
            File.write(main_secrets_file, "ci_api_token: new-token\n")

            # Setup worktree with OLD .wralph contents
            FileUtils.mkdir_p(File.join(worktree_path, '.git'))
            FileUtils.mkdir_p(File.join(worktree_path, '.wralph'))

            worktree_secrets_file = File.join(worktree_path, '.wralph', 'secrets.yaml')
            File.write(worktree_secrets_file, "ci_api_token: old-token\n")

            # Mock git rev-parse
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('git rev-parse --show-toplevel')
              .and_return([main_repo, '', true])

            # Mock the worktree check
            allow(Wralph::Interfaces::Shell).to receive(:run_command)
              .with('test -f "$(git rev-parse --git-dir)/commondir"')
              .and_return(['', '', false])

            # Mock Repo methods
            allow(Wralph::Interfaces::Repo).to receive(:repo_root).and_return(main_repo)
            allow(Wralph::Interfaces::Repo).to receive(:branch_name).with(issue_number).and_return(branch_name)
            allow(Wralph::Interfaces::Repo).to receive(:wralph_dir).and_return(File.join(main_repo, '.wralph'))

            # Mock get_worktrees
            allow(Wralph::Interfaces::Shell).to receive(:get_worktrees).and_return([
              {'branch' => branch_name, 'path' => worktree_path}
            ])

            Dir.chdir(main_repo) do
              described_class.run(issue_number)
            end

            # Verify the file was overwritten with new content
            expect(File.read(worktree_secrets_file)).to eq("ci_api_token: new-token\n")
          end
        end
      end
    end
  end
end
