# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Wralph::Interfaces::Repo do
  describe '.repo_root' do
    it 'finds the git repository root' do
      # Create a temporary directory structure with .git
      Dir.mktmpdir do |tmpdir|
        git_dir = File.join(tmpdir, '.git')
        Dir.mkdir(git_dir)

        subdir = File.join(tmpdir, 'some', 'nested', 'directory')
        FileUtils.mkdir_p(subdir)

        Dir.chdir(subdir) do
          # Dir.pwd resolves symlinks (e.g., /var -> /private/var on macOS)
          # so we need to compare using the actual resolved path
          actual_root = Wralph::Interfaces::Repo.repo_root
          # Normalize tmpdir the same way Dir.pwd does
          expected_root = Dir.chdir(tmpdir) { Dir.pwd }
          expect(actual_root).to eq(expected_root)
        end
      end
    end

    it 'returns current directory if no .git found' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Dir.pwd resolves symlinks, so normalize both sides the same way
          actual_root = Wralph::Interfaces::Repo.repo_root
          expected_root = Dir.pwd
          expect(actual_root).to eq(expected_root)
        end
      end
    end
  end

  describe '.wralph_dir' do
    it 'returns the correct path for .wralph directory' do
      expected_path = File.join(Wralph::Interfaces::Repo.repo_root, '.wralph')
      expect(Wralph::Interfaces::Repo.wralph_dir).to eq(expected_path)
    end
  end

  describe '.plans_dir' do
    it 'returns the correct path for plans directory' do
      expected_path = File.join(Wralph::Interfaces::Repo.repo_root, '.wralph', 'plans')
      expect(Wralph::Interfaces::Repo.plans_dir).to eq(expected_path)
    end
  end

  describe '.plan_file' do
    it 'returns the correct path for a plan file' do
      issue_number = '123'
      expected_path = File.join(Wralph::Interfaces::Repo.repo_root, '.wralph', 'plans', "plan_#{issue_number}.md")
      expect(Wralph::Interfaces::Repo.plan_file(issue_number)).to eq(expected_path)
    end
  end

  describe '.env_file' do
    it 'returns the .env file path in repo root' do
      expected_path = File.join(Wralph::Interfaces::Repo.repo_root, '.env')
      expect(Wralph::Interfaces::Repo.env_file).to eq(expected_path)
    end
  end

  describe '.secrets_file' do
    it 'returns the secrets.yaml file path in .wralph directory' do
      expected_path = File.join(Wralph::Interfaces::Repo.repo_root, '.wralph', 'secrets.yaml')
      expect(Wralph::Interfaces::Repo.secrets_file).to eq(expected_path)
    end
  end

  describe '.failure_details_file' do
    it 'returns the correct path for a failure details file' do
      branch_name = 'issue-123'
      retry_count = 1
      expected_path = File.join(Wralph::Interfaces::Repo.tmp_dir, "#{branch_name}_failure_details_#{retry_count}_#{retry_count}.txt")
      expect(Wralph::Interfaces::Repo.failure_details_file(branch_name, retry_count)).to eq(expected_path)
    end

    it 'sanitizes branch names with slashes to prevent directory creation' do
      branch_name = 'nickk/issue-123'
      retry_count = 2
      # The slash should be replaced with a dash
      expected_path = File.join(Wralph::Interfaces::Repo.tmp_dir, "nickk-issue-123_failure_details_#{retry_count}_#{retry_count}.txt")
      expect(Wralph::Interfaces::Repo.failure_details_file(branch_name, retry_count)).to eq(expected_path)
    end

    it 'sanitizes branch names with multiple slashes' do
      branch_name = 'team/user/feature-456'
      retry_count = 3
      # All slashes should be replaced with dashes
      expected_path = File.join(Wralph::Interfaces::Repo.tmp_dir, "team-user-feature-456_failure_details_#{retry_count}_#{retry_count}.txt")
      expect(Wralph::Interfaces::Repo.failure_details_file(branch_name, retry_count)).to eq(expected_path)
    end
  end

  describe '.branch_name' do
    before do
      Wralph::Config.reset
    end

    it 'uses default template when no config exists' do
      Dir.mktmpdir do |tmpdir|
        FileUtils.mkdir_p(File.join(tmpdir, '.git'))

        Dir.chdir(tmpdir) do
          result = Wralph::Interfaces::Repo.branch_name('123')
          expect(result).to eq('issue-123')
        end
      end
    end

    it 'uses custom template from config' do
      Dir.mktmpdir do |tmpdir|
        FileUtils.mkdir_p(File.join(tmpdir, '.git'))
        wralph_dir = File.join(tmpdir, '.wralph')
        FileUtils.mkdir_p(wralph_dir)

        config_data = {
          'repo' => {
            'branch_name' => "feature/ticket-\#{identifier}"
          }
        }
        File.write(File.join(wralph_dir, 'config.yaml'), config_data.to_yaml)

        Dir.chdir(tmpdir) do
          result = Wralph::Interfaces::Repo.branch_name('456')
          expect(result).to eq('feature/ticket-456')
        end
      end
    end

    it 'handles template with multiple variables' do
      Dir.mktmpdir do |tmpdir|
        FileUtils.mkdir_p(File.join(tmpdir, '.git'))
        wralph_dir = File.join(tmpdir, '.wralph')
        FileUtils.mkdir_p(wralph_dir)

        config_data = {
          'repo' => {
            'branch_name' => "bugfix-\#{identifier}"
          }
        }
        File.write(File.join(wralph_dir, 'config.yaml'), config_data.to_yaml)

        Dir.chdir(tmpdir) do
          result = Wralph::Interfaces::Repo.branch_name('789')
          expect(result).to eq('bugfix-789')
        end
      end
    end
  end
end
