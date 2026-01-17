# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe Nitl::Interfaces::Repo do
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
          actual_root = Nitl::Interfaces::Repo.repo_root
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
          actual_root = Nitl::Interfaces::Repo.repo_root
          expected_root = Dir.pwd
          expect(actual_root).to eq(expected_root)
        end
      end
    end
  end

  describe '.nitl_dir' do
    it 'returns the correct path for .nitl directory' do
      expected_path = File.join(Nitl::Interfaces::Repo.repo_root, '.nitl')
      expect(Nitl::Interfaces::Repo.nitl_dir).to eq(expected_path)
    end
  end

  describe '.plans_dir' do
    it 'returns the correct path for plans directory' do
      expected_path = File.join(Nitl::Interfaces::Repo.repo_root, '.nitl', 'plans')
      expect(Nitl::Interfaces::Repo.plans_dir).to eq(expected_path)
    end
  end

  describe '.plan_file' do
    it 'returns the correct path for a plan file' do
      issue_number = '123'
      expected_path = File.join(Nitl::Interfaces::Repo.repo_root, '.nitl', 'plans', "plan_gh_issue_no_#{issue_number}.md")
      expect(Nitl::Interfaces::Repo.plan_file(issue_number)).to eq(expected_path)
    end
  end

  describe '.env_file' do
    it 'returns the .env file path in repo root' do
      expected_path = File.join(Nitl::Interfaces::Repo.repo_root, '.env')
      expect(Nitl::Interfaces::Repo.env_file).to eq(expected_path)
    end
  end

  describe '.secrets_file' do
    it 'returns the secrets.yaml file path in .nitl directory' do
      expected_path = File.join(Nitl::Interfaces::Repo.repo_root, '.nitl', 'secrets.yaml')
      expect(Nitl::Interfaces::Repo.secrets_file).to eq(expected_path)
    end
  end
end
